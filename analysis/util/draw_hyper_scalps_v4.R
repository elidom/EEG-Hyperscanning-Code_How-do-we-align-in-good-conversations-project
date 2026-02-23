# ------------------------------------------------------------------------------
# Hyperscanning ROI-to-ROI Plotting Helper
#
# Usage:
# - Load this script, then call `draw_hyper_plot()` with:
#     from_ROI: vector of speaker ROIs
#     to_ROI:   vector of listener ROIs (same length as from_ROI)
#     effect_values: numeric vector used for line width + color scaling
# - Optionally, adjust `basewidth` to set the minimum width of plotted lines.
#   `basewidth + abs(effect_values_use[i])` should yield a positive number.
# - The color palette can take any number of colors.
# - Returns a ggplot object showing both scalp maps, ROI polygons, and
#   curved connections between ROI pairs.
#
# Requirements: tidyverse, sf, smoothr, concaveman. Channel locations must be in
#   `supps/chanLocs.csv`.
#
# Example calls to the function are at the bottom of this script.
# ------------------------------------------------------------------------------

library(tidyverse)
library(concaveman)
library(sf)
library(smoothr)

# --------------------
# Parameters / montage
# --------------------

electrodes <- c(
  "Fp1", "Fz", "F3", "F7", "FT9", "FC5", "FC1", "C3", "T7", "TP9", 
  "CP5", "CP1", "Pz", "P3", "P7", "O1", "Oz", "O2", "P4", "P8", 
  "TP10", "CP6", "CP2", "Cz", "C4", "T8", "FT10", "FC6", "FC2", 
  "F4", "F8", "Fp2", "FCz"
)


roi_mapping <- list(
  "Left anterior" = c("Fp1", "F3", "F7"),
  "Right anterior" = c("Fp2", "F4", "F8"),
  "Medial anterior" = c("Fz", "FC1", "FC2", "FCz"),
  "Medial central" = c("C3", "Cz", "C4", "CP1", "CP2"),
  "Left temporal" = c("FC5", "T7", "CP5"),
  "Right temporal" = c("FC6", "T8", "CP6")
)


# --------------------
# Channel locations
# --------------------

chanLocs <- read_csv("supps/chanLocs.csv") %>%
  rename(electrode = labels) %>% 
  filter(electrode %in% electrodes)

# degrees -> radians
chanLocs$radianTheta <- pi / 180 * chanLocs$theta

# cartesian
chanLocs <- chanLocs %>%
  mutate(
    x = .$radius * sin(.$radianTheta),
    y = .$radius * cos(.$radianTheta)
  ) %>%
  select(electrode, x, y)

# --------------------
# Visual primitives
# --------------------
theme_topo <- function(base_size = 12) {
  theme_bw(base_size = base_size) %+replace%
    theme(
      rect       = element_blank(),
      line       = element_blank(),
      axis.text  = element_blank(),
      axis.title = element_blank()
    )
}

circleFun <- function(center = c(0, 0), diameter = 1, npoints = 100) {
  r  <- diameter / 2
  tt <- seq(0, 2 * pi, length.out = npoints)
  xx <- center[1] + r * cos(tt)
  yy <- center[2] + r * sin(tt)
  return(data.frame(x = xx, y = yy))
}

headShape <- circleFun(c(0, 0), round(max(chanLocs$x)), npoints = 100)
nose      <- data.frame(x = c(-0.075, 0, 0.075), y = c(0.495, 0.575, 0.495))

headShape2 <- headShape %>% mutate(y = y+1.5)
nose2       <- data.frame(x = c(-0.075, 0, 0.075), y = c(0.495+0.5, 0.415+0.5, 0.495+0.5))

chanLocs2 <- chanLocs %>% mutate(x = -x, y = -y+1.5)


# --------------------
# ROI polygon helpers
# --------------------
roi_hull <- function(points, expand = 0.23, smooth_passes = 1) {
  if (nrow(points) < 3) return(NULL)
  hull_indices <- chull(points$x, points$y)
  hull_pts <- points[c(hull_indices, hull_indices[1]), c("x", "y")]
  polygon <- st_sfc(st_polygon(list(as.matrix(hull_pts))))
  for (i in seq_len(max(1, smooth_passes))) {
    polygon <- smooth(polygon, method = "chaikin")
  }
  box <- st_bbox(polygon)
  diag_len <- sqrt((box$xmax - box$xmin)^2 + (box$ymax - box$ymin)^2)
  polygon <- st_buffer(polygon, dist = diag_len * expand)
  coords <- st_coordinates(st_cast(polygon, "POLYGON"))
  tibble(x = coords[, 1], y = coords[, 2])
}

roi_hull_concave <- function(points, concavity = 4, expansion = 1.8) {
  hull_indices <- chull(points$x, points$y)
  hull_pts <- points[c(hull_indices, hull_indices[1]), c("x", "y")]
  hull_pts <- concaveman(as.matrix(hull_pts[, c("x", "y")]), concavity = 4)
  center_x <- mean(hull_pts[,1])
  center_y <- mean(hull_pts[,2])
  hull_pts <- tibble(x = hull_pts[,1], y = hull_pts[,2])
  expanded_hull <- hull_pts %>%
    mutate(
      x = center_x + (x - center_x) * expansion,
      y = center_y + (y - center_y) * expansion
    )
  return(expanded_hull)
}

all_ROIs <- names(roi_mapping)
# roi_mapping["right_temporal"]

# --------------------
# Plot function 
# --------------------
draw_hyper_plot <- function(from_ROI, to_ROI, curvatures,
                            ROIcol = "#93BFC7",
                            effect_values = NULL,
                            color_palette = c("#ffc75a","#ff733e", "#f34c2a"),
                            basewidth = -1.5,
                            col_min = NULL,
                            col_max = NULL) {
  # --------------------
  # Styling
  # --------------------
  roi_fill_alpha = 0.3
  roi_outline_linewidth = 1
  electrode_circle_color = "#e50000"
  electrode_circle_size = 3
  scalp_linewidth = 1.5
  nose_linewidth = 1.25
  
  nconns <- length(from_ROI)
  roi_electrodes_from <- unlist(roi_mapping[from_ROI])
  roi_electrodes_to <- unlist(roi_mapping[to_ROI])
  
  hulls_from <- lapply(all_ROIs, function(roi){
    electrodes2 <- roi_mapping[[roi]]
    roi_points <- chanLocs %>% filter(electrode %in% electrodes2)
    if (roi == "Medial central") {
      expanded_hull <- roi_hull(points = roi_points, expand = 0.13)
    } else {
      expanded_hull <- roi_hull(points = roi_points, expand = 0.25)
    }
  })
  names(hulls_from) <- all_ROIs
  
  hulls_to <- lapply(all_ROIs, function(roi){
    electrodes2 <- roi_mapping[[roi]]
    roi_points <- chanLocs2 %>% filter(electrode %in% electrodes2)
    if (roi == "Medial central") {
      expanded_hull <- roi_hull(points = roi_points, expand = 0.13)
    } else {
      expanded_hull <- roi_hull(points = roi_points, expand = 0.25)
    }
  })
  names(hulls_to) <- all_ROIs
  
  chanLocs <- chanLocs %>%
    mutate(highlight = ifelse(electrode %in% roi_electrodes_from, TRUE, FALSE))
  chanLocs2 <- chanLocs2 %>%
    mutate(highlight = ifelse(electrode %in% roi_electrodes_to, TRUE, FALSE))
  
  p <- ggplot(headShape, aes(x =x, y=y)) +
    geom_path(linewidth = scalp_linewidth) +
    geom_line(data = nose, aes(x, y, z = NULL), linewidth = nose_linewidth) +
    geom_path(data = headShape2,linewidth = scalp_linewidth) +
    geom_line(data = nose2, aes(x, y, z = NULL), linewidth = nose_linewidth) +
    theme_topo() +
    coord_equal() +
    geom_point(data = chanLocs, aes(x, y, fill = highlight), shape = 21, size = electrode_circle_size, stroke = 1) +
    geom_point(data = chanLocs2, aes(x, y, fill = highlight), shape = 21, size = electrode_circle_size, stroke = 1) +
    scale_fill_manual(values = c("white", electrode_circle_color)) +
    theme(legend.position = "none")
  
  for (roi in all_ROIs) {
    if (!is.null(hulls_from[[roi]])) {
      p <- p +
        geom_polygon(data = hulls_from[[roi]], aes(x, y), fill = ROIcol, alpha = roi_fill_alpha) +
        geom_path(data = hulls_from[[roi]], aes(x, y), color = ROIcol, linewidth = roi_outline_linewidth)
    }
  }
  
  for (roi in all_ROIs) {
    if (!is.null(hulls_to[[roi]])) {
      p <- p +
        geom_polygon(data = hulls_to[[roi]], aes(x, y), fill = ROIcol, alpha = roi_fill_alpha) +
        geom_path(data = hulls_to[[roi]], aes(x, y), color = ROIcol, linewidth = roi_outline_linewidth)
    }
  }
  
  effect_values_use <- effect_values
  
  if (length(effect_values_use) != nconns) {
    stop("effect_values (if provided) must have same length as number of connections")
  }
  

  mags <- effect_values_use
  
  lo <- if (is.null(col_min)) min(mags, na.rm = TRUE) else col_min
  hi <- if (is.null(col_max)) max(mags, na.rm = TRUE) else col_max

  norm_mags <- (mags - lo) / (hi - lo)
  
  norm_mags <- pmin(1, pmax(0, norm_mags))
  
  # # handle constant vector 
  # if (all(is.na(mags)) || (max(mags, na.rm = TRUE) - min(mags, na.rm = TRUE)) == 0) {
  #   norm_mags <- rep(0.5, length(mags))
  # } else {
  #   norm_mags <- (mags - min(mags, na.rm = TRUE)) / (max(mags, na.rm = TRUE) - min(mags, na.rm = TRUE))
  # }
  
  # tmp:
  # mags2 <- c(mags, 2.5, 4.5)
  # norm_mags <- (mags2 - min(mags2, na.rm = TRUE)) / (max(mags2, na.rm = TRUE) - min(mags2, na.rm = TRUE))
  
  pal_fun <- grDevices::colorRampPalette(color_palette)
  npal <- max(2, length(color_palette)*50) # fine-grained palette
  pal_vec <- pal_fun(npal)
  cols_for_conns <- pal_vec[ pmax(1, round(1 + norm_mags * (npal - 1))) ]
  
  # cols_for_conns <- cols_for_conns[1:8]
  
  # # Trying
  # 
  if (missing(curvatures) || length(curvatures) != nconns) {
    # params (tweak if you want stronger/weaker curves)
    max_curv <- 0.5        # max absolute curvature
    min_curv <- 0.05       # minimum curvature
    parallel_spread <- 0.18 # how far apart parallel edges are (fraction of base)
    
    # helper: centroid
    centroid <- function(h) c(mean(h$x, na.rm=TRUE), mean(h$y, na.rm=TRUE))
    starts <- lapply(from_ROI, function(r) centroid(hulls_from[[r]]))
    ends   <- lapply(to_ROI,   function(r) centroid(hulls_to[[r]]))
    
    # distances and normalized [0,1]
    dists <- mapply(function(a,b) sqrt((a[1]-b[1])^2 + (a[2]-b[2])^2), starts, ends)
    if (all(is.na(dists)) || max(dists, na.rm=TRUE)==min(dists, na.rm=TRUE)) {
      normd <- rep(0.5, length(dists))
    } else {
      normd <- (dists - min(dists, na.rm=TRUE)) / (max(dists, na.rm=TRUE) - min(dists, na.rm=TRUE))
    }
    
    # base magnitude: closer -> larger curvature
    base_mag <- pmax(min_curv, max_curv * (1 - normd))
    
    
    pair_ids <- paste(from_ROI, "->", to_ROI)
    tbl <- table(pair_ids)
    idx_within <- integer(nconns)
    counters <- list()
    for (i in seq_len(nconns)) {
      id <- pair_ids[i]
      if (is.null(counters[[id]])) counters[[id]] <- 0
      counters[[id]] <- counters[[id]] + 1
      idx_within[i] <- counters[[id]]
    }
    pair_count <- as.integer(tbl[pair_ids])
    
    # assemble curvatures
    computed <- numeric(nconns)
    for (i in seq_len(nconns)) {
      s <- starts[[i]]; e <- ends[[i]]
      if (any(is.na(s)) || any(is.na(e))) { computed[i] <- 0; next }
      # sign: make arc bow outward horizontally
      sign_h <- ifelse(s[1] < e[1], -1, 1)
      # parallel offset
      n_same <- pair_count[i]
      pos <- idx_within[i]
      if (n_same > 1) {
        seq_idx <- seq(-(n_same-1)/2, (n_same-1)/2, length.out = n_same)
        offset <- seq_idx[pos] * (parallel_spread * base_mag[i])
      } else offset <- 0
      mag <- base_mag[i] + offset
      computed[i] <- sign_h * mag
    }
    
    curvatures <- computed
  }
  # --- end simple curvature compute ---
  
  # --- draw curves
  effect_values_use2 <- norm_mags*3
  
  for (i in 1:nconns) {
    spkrROI <- from_ROI[i]
    lnrROI  <- to_ROI[i]
    
    # gracefully handle missing hulls
    if (is.null(hulls_from[[spkrROI]]) || is.null(hulls_to[[lnrROI]])) next
    
    xpoints_start <- hulls_from[[spkrROI]]$x
    xpoints_end <- hulls_to[[lnrROI]]$x
    ypoints_start <-  hulls_from[[spkrROI]]$y
    ypoints_end <- hulls_to[[lnrROI]]$y
    
    curve_data <- data.frame(
      x = mean(xpoints_start, na.rm = TRUE),
      y = mean(ypoints_start, na.rm = TRUE),
      xend = mean(xpoints_end, na.rm = TRUE),
      yend = mean(ypoints_end, na.rm = TRUE)
    )
    
    # colour for this connection
    this_col <- cols_for_conns[i]
    
    # linewidth
    # this_lwd <- -1.5+effect_values_use[i]
    this_lwd <- basewidth + abs(effect_values_use2[i])
    
    # # 
    
    p <- p +
      geom_curve(
        data = curve_data,
        aes(x = x, y = y, xend = xend, yend = yend),
        curvature = curvatures[i],
        alpha = .9,
        linewidth = this_lwd,
        color = this_col
      )
  }
  
  return(p)
}



