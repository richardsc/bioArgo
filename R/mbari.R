#' @import oce
NULL

#' Read an MBARI BioArgo file
#'
#' Reads a "Bio-Argo" formatted file into an \code{oce} \code{argo} object.
#'
#' @param file local filename or connection from which to read data. In the case where the argument \code{url=TRUE}, it can specify the float file without the \code{.TXT} extention.
#' @param url logical indicating if the file should be obtained directly via download from the MBARI website. Will also check to see if there is a locally cached copy in the current working directory (see \code{cache} argument).
#' @param cache ignored if \code{url=FALSE}. Logical indicating if the downloaded file should be cached locally. 
#' @details Reads the plain-text csv files obtained from \code{http://www.mbari.org/science/upper-ocean-systems/chemical-sensor-group/floatviz/}
#' @return An \code{oce} \code{argo} object, containing the extra data columns
#'   corresponding to the biological data.
#' @author Clark Richards, Dan Kelley, Cara Wilson
#' @seealso \code{read.argo}, \code{as.argo}, and \code{as.section} from the
#'   \code{oce} package
#' @examples
#' d <- read.argo.mbari(system.file("extdata", "5145HawaiiQc.txt", package="mbari"))
#' ds <- as.section(d)
#' par(mfrow=c(2, 1))
#' plot(d)
#' plot(ds, xtype='time', which='oxygen')
#' @export
read.argo.mbari <- function(file, url=FALSE, cache=FALSE)
{
    filename <- ""
    if (!url & is.character(file)) {
        filename <- fullFilename(file)
        file <- file(file, "r")
        on.exit(close(file))
    } else if (url & is.character(file)) {
        ## check for the .txt extension
        hasTXT <- ifelse(length(unlist(strsplit(file, '.', fixed=TRUE))) > 1, TRUE, FALSE)
        if (!hasTXT) file <- paste0(file, '.txt')
        if (cache) filename <- file else filename <- tempfile()
        baseurl <- 'http://www3.mbari.org/lobo/Data/FloatVizData/'
        qc <- length(grep('QC', file)) > 0
        if (!qc) {
            url <- paste0(baseurl, file)
        } else {
            url <- paste0(baseurl, 'QC/', file)
        }
        ## does the file already exist in wd?
        if (sum(grep(file, list.files())) > 0) {
            message(paste0('Loading cached file ', file))
            filename <- file
        } else {
            message(paste0('Downloading to ', filename))
            download.file(url, filename)
        }
        file <- file(filename, "r")
        on.exit(close(file))
    }
    header <- readLines(file, encoding="latin1", n=100)
    isHeader <- grepl("^//", header, useBytes=TRUE)
    header <- header[isHeader]
    skip <- length(header)
    seek(file, 0, "start")
    data <- read.delim(file, sep="\t", skip=skip, encoding="latin1")
    id <- regmatches(data$Cruise[1], gregexpr("[0-9]+", data$Cruise[1]))[[1]]

                                        # this will strip out lines with empty parameters
    data <- subset(data, !is.na(Depth.m.))

    names <- names(data)

    ## all possible fields:
    ## Nitrate[µM]
    ## Depth[m]
    ## mon/day/yr
    ## Salinity
    ## Temperature[°C]
    ## Density
    ## Oxygen[µM]
    ## OxygenSat[%]
    ## Chlorophyll[µg/l]
    ## BackScatter[/m/sr]
    ## CDOM[PPB]
    ## pHinsitu[Total]
    ## pH25C[Total]
    ## Lon [°E]
    ## Lat [°N]
    names <- gsub("Bot..Depth..m.", "waterDepth", names)
    names <- gsub("Cruise", "cruise", names)
    names <- gsub("Density", "density", names)
    names <- gsub("Depth.m.", "pressure", names)
    names <- gsub("Lat.*", "latitude", names)
    names <- gsub("Lon.*", "longitude", names)
    names <- gsub("Nitrate.*", "nitrate", names)
    names <- gsub("Oxygen\\..*", "oxygen", names)
    names <- gsub("OxygenSat.*", "oxygenSaturation", names)
    names <- gsub("Salinity", "salinity", names)
    names <- gsub("Station", "station", names)
    names <- gsub("Temperature.*", "temperature", names)
    names <- gsub("Type", "type", names)
    names <- gsub("Chlorophyll\\..*", "chlorophyll", names)
    names <- gsub("pHinsitu.Total.", "pHinsitu", names)
    names <- gsub("pH25C.Total.", "pH25C", names)
    names <- gsub("BackScatter\\..*", "backscatter", names)
    ## print(names)
    time <- as.POSIXct(paste(data$mon.day.yr, " ", data$hh.mm, ":00", sep=""), format="%m/%d/%Y %H:%M:%S", tz="UTC")

    isQF <- grepl("^QF", names)
    flags <- data[,isQF]
    names(flags) <- names[which(isQF)-1]
    data <- data[,!isQF]
    names(data) <- names[!isQF]
    ## Trim two cols that held time; add in a time column
    ##>  data <- data[, -which(names=="mon.day.yr"|names=="hh.mm")] # CR had no ","
    data$time <- time

                                        #sigmaT <- swSigmaT(data$salinity,data$temperature,data$pressure,eos="gsw")

    D <- split(data, factor(data$station))
    F <- split(flags, factor(data$station))
    nprofiles <- length(D)
    nlevels <- length(D[[1]]$pressure)

    time <- unique(data$time)
    maxPlevels <- max(unlist(lapply(D, function(x) length(x$pressure))))
    longitude <- unlist(lapply(D, function(x) x$longitude[1]), use.names = FALSE)
    latitude <- unlist(lapply(D, function(x) x$latitude[1]), use.names = FALSE)

    makeMatrix <- function(x, field) {
        n1 <- length(x)
        n2 <- max(unlist(lapply(x, function(x) length(x$pressure))))
        res <- matrix(NA, nrow=n1, ncol=n2)
        for (i in 1:length(x)) {
            n <- length(x[[i]][[field]])
            res[i, 1:n] <- rev(x[[i]][[field]])
        }
        return(t(res))
    }

    pressure <- makeMatrix(D, 'pressure')
    pressureFlag <- makeMatrix(F, 'pressure')
    temperature <- makeMatrix(D, 'temperature')
    temperatureFlag <- makeMatrix(F, 'temperature')
    salinity <- makeMatrix(D, 'salinity')
    salinityFlag <- makeMatrix(F, 'salinity')
    oxygen <- makeMatrix(D, 'oxygen')
    oxygenFlag <- makeMatrix(F, 'oxygen')
    oxygenSaturation <- makeMatrix(D, 'oxygenSaturation')
    oxygenSaturationFlag <- makeMatrix(F, 'oxygenSaturation')
    if ("nitrate" %in% names) {
        nitrate <- makeMatrix(D, 'nitrate')
        nitrateFlag <- makeMatrix(F, 'nitrate')
    }
    if ("chlorophyll" %in% names) {
        chlorophyll <- makeMatrix(D, 'chlorophyll')
        chlorophyllFlag <- makeMatrix(F, 'chlorophyll')
    }
    if ("backscatter" %in% names) {
        backscatter <- makeMatrix(D, 'backscatter')
        backscatterFlag <- makeMatrix(F, 'backscatter')
    }
    if ("pHinsitu" %in% names) {
        pHinsitu <- makeMatrix(D, 'pHinsitu')
        pHinsituFlag <- makeMatrix(F, 'pHinsitu')
    }
    if ("pH25C" %in% names) {
        pH25C <- makeMatrix(D, 'pH25C')
        pH25CFlag <- makeMatrix(F, 'pH25C')
    }

    d <- as.argo(time=time, longitude=ifelse(longitude>180, longitude-360, longitude),
                 latitude=latitude,
                 pressure=pressure, temperature=temperature, salinity=salinity,
                 filename=filename, id=id)
    d <- oceSetData(d, 'oxygen', oxygen, units=list(unit=expression(mu*M), scale=""))
    d <- oceSetData(d, 'oxygenSaturation', oxygenSaturation, units=list(unit=expression(), scale=""))
    d <- oceSetMetadata(d, 'flags', list(pressure=pressureFlag, temperature=temperatureFlag,
                                         salinity=salinityFlag,oxygen=oxygenFlag,oxygenSaturation=oxygenSaturationFlag))
    if ("nitrate" %in% names)  {
        d <- oceSetData(d, 'nitrate', nitrate, units=list(unit=expression(mu*M), scale=""))
        d@metadata$flags$nitrate <- nitrateFlag
    }
    if ("chlorophyll" %in% names)  {
        d <- oceSetData(d, 'chlorophyll', chlorophyll, units=list(unit=expression(mu*g/l), scale=""))
        d@metadata$flags$chlorophyll <- chlorophyllFlag
    }
    if ("backscatter" %in% names) {
        d <- oceSetData(d, 'backscatter', backscatter, units=list(unit=expression(1/(m*sr)), scale=""))
        d@metadata$flags$backscatter <- backscatterFlag
    }
    if ("pHinsitu" %in% names)  {
        d <- oceSetData(d, 'pHinsitu', pHinsitu, units=list(unit=expression(Total), scale=""))
        d@metadata$flags$pHinsitu <- pHinsituFlag
    }
    if ("pH25C" %in% names)  {
        d <- oceSetData(d, 'pH25C', pH25C, units=list(unit=expression(Total), scale=""))
        d@metadata$flags$pH25C <- pH25CFlag
    }

    d
}
