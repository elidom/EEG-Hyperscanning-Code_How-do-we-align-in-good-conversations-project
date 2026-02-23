
# Utility script to create scalp/topographic raster plots from electrode-level
# values (e.g., mutual information, power, etc.).


required_pkgs <- c("tidyverse", "akima", "scales")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  stop(sprintf(
    "Missing required packages: %s.\nInstall with install.packages(...) before sourcing this script.",
    paste(missing_pkgs, collapse = ", ")
  ))
}

library(tidyverse)
library(akima)
library(scales)


# Helper: circle generator
# -------------------------
circleFun <- function(center = c(0, 0), diameter = 1, npoints = 100) {
  r <- diameter / 1.66
  tt <- seq(0, 2 * pi, length.out = npoints)
  xx <- center[1] + r * cos(tt)
  yy <- center[2] + r * sin(tt)
  data.frame(x = xx, y = yy)
}


theme_topo <- function(base_size = 12) {
  ggplot2::theme_bw(base_size = base_size) %+replace%
    ggplot2::theme(
      rect = element_blank(),
      line = element_blank(),
      axis.text = element_blank(),
      axis.title = element_blank(),
      panel.grid = element_blank()
    )
}


topo_pal <- function(n = 10) {
  colorRampPalette(
    c("#00007F", "blue", "#007FFF", "cyan", "#7FFF7F", "yellow", "#FF7F00", "red", "#7F0000")
  )(n)
}


# Main function: create_scalp

# create_scalp(
#   data,
#   time1 = 50,
#   time2 = 200,
#   max_val = NULL,
#   min_val = NULL,
#   colorbar = TRUE,
#   gridRes = 200
# )


create_scalp <- function(data,
                         time1 = 50,
                         time2 = 200,
                         max_val = NULL,
                         min_val = NULL,
                         colorbar = TRUE,
                         gridRes = 200,
                         legendt = " ") {
  # Input checks
  if (!all(c("x", "y", "Lag", "MI_value") %in% colnames(data))) {
    stop("Input data must contain columns: x, y, Lag, MI_value")
  }
  
  if (!is.numeric(gridRes) || gridRes < 10) {
    stop("gridRes should be an integer >= 10")
  }
  
  # Subset the data to the requested time window 
  data2plot <- dplyr::filter(data, Lag > time1 & Lag < time2)
  if (nrow(data2plot) == 0) {
    stop("No rows in the requested Lag window. Check time1/time2 or the Lag units.")
  }
  
  # Determine plotting limits (do not use base min/max names)
  if (is.null(max_val)) max_val <- max(data2plot$MI_value, na.rm = TRUE)
  if (is.null(min_val)) min_val <- min(data2plot$MI_value, na.rm = TRUE)
  
  # Interpolate onto a regular grid using akima::interp 
  tmpTopo <- with(data2plot,
                  akima::interp(
                    x = x, y = y, z = MI_value,
                    xo = seq(min(x) * 2, max(x) * 2, length = gridRes),
                    yo = seq(min(y) * 2, max(y) * 2, length = gridRes),
                    linear = FALSE, extrap = TRUE, duplicate = "mean"
                  ))
  
  # Convert the interpolation output to a long data.frame
  interpTopo <- data.frame(x = tmpTopo$x, tmpTopo$z)
  # name the columns correctly; tmpTopo$y corresponds to the column names after x
  colnames(interpTopo)[2:(length(tmpTopo$y) + 1)] <- as.character(tmpTopo$y)
  
  interpTopo <- tidyr::gather(interpTopo, key = "y", value = "value", -x, convert = TRUE)
  
  # Mask to an approximately circular scalp region
  interpTopo$incircle <- sqrt(interpTopo$x^2 + interpTopo$y^2) < 0.65
  interpTopo <- dplyr::filter(interpTopo, incircle)
  
  # Pre-compute rings
  maskRing <- circleFun(diameter = 1.5)
  headShape <- circleFun(c(0, 0), diameter = round(max(data$x, na.rm = TRUE)), npoints = 100)
  nose <- data.frame(x = c(-0.075, 0, 0.075), y = c(0.605, 0.685, 0.605))
  
  # Guide selection 
  guide_val <- if (colorbar) "colorbar" else "none"
  
  # Build the plot 
  pn <- ggplot2::ggplot(interpTopo, ggplot2::aes(x = x, y = y, fill = value)) +
    ggplot2::geom_raster() +
    theme_topo() +
    ggplot2::scale_fill_gradientn(
      colours = topo_pal(10),
      limits = c(min_val, max_val),
      guide = guide_val,
      labels = scales::label_number(suffix = " ", accuracy = 0.01),
      oob = scales::squish
    ) +
    ggplot2::geom_path(
      data = maskRing,
      aes(x = x, y = y, fill = NULL),
      colour = "white",
      size = 6
    ) +
    ggplot2::geom_path(data = headShape, ggplot2::aes(x = x, y = y, fill = NULL), size = 1.5) +
    ggplot2::geom_path(data = nose, ggplot2::aes(x = x, y = y, fill = NULL), size = 1.5) +
    ggplot2::coord_equal() +
    ggplot2::labs(fill = legendt, title = NULL) +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.background = ggplot2::element_rect(fill = "transparent", colour = NA),
      plot.title = ggplot2::element_text(size = 9, hjust = 0.5, margin = ggplot2::margin(b = -5)),
      legend.key.width = grid::unit(.2, "cm"),
      legend.key.height = grid::unit(1, "cm"),
      legend.text = ggplot2::element_text(size = 10)
    )
  
  return(pn)
}

