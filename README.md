# Read MBARI BioArgo files into R

This package provides the facility to read the [MBARI BioArgo float data](http://www.mbari.org/science/upper-ocean-systems/chemical-sensor-group/floatviz/) into R, using the `argo` class inherited from the [`oce` package](http://dankelley.github.io/oce/).

## Installation

The `mbari` package is not currently on CRAN. The best way to install `mbari` is to use the `devtools` package:
```r
library(devtools)
install_github('richardsc/mbari', ref='master')
```

## Example

Load one of the included data files, and plot an oxygen section using a [`cmocean`](http://matplotlib.org/cmocean/) colour scheme:
```r
library(oce)
library(mbari)
d <- read.argo.mbari('inst/extdata/5145HawaiiQc.txt')
plot(as.section(d), which='oxygen', xtype='time', ztype='image', zcol=oceColorsOxygen)
```
![5145Example](5145.png)
