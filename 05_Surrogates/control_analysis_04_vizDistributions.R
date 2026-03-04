# -------------------------------------------------------------------------
#  CONTROL ANALYSIS – Surrogate Null Distributions Visualization
#
#  Author: Marcos E. Domínguez Arriola
#  Repository: https://github.com/elidom/EEG-Hyperscanning-Code_How-do-we-align-in-good-conversations-project
#  Project: Domínguez-Arriola, Lam, Pérez, & Pell (under review)
#           How Do We Align in Good Conversation?
#
#  Visualizes permutation-based null distributions derived from
#  surrogate (shuffled-dyad) datasets and compares them with the
#  empirical statistics observed in the real dyads.
#
# -------------------------------------------------------------------------


library(tidyverse)

alpha_concurrent_Fs  <- readRDS("../7_Analysis/data/10_surrogate_outputs/alpha_concurrent_surrogate_Fs.rds")
alpha_recurrent_emts <- readRDS("../7_Analysis/data/10_surrogate_outputs/alpha_recurrent_surrogate_emts.rds")
theta_concurrent_emts <- readRDS("../7_Analysis/data/10_surrogate_outputs/theta_concurrent_surrogate_emts.rds")
theta_recurrent_emts <- readRDS("../7_Analysis/data/10_surrogate_outputs/theta_recurrent_surrogate_emts.rds")

## 1. Concurrent Alpha

realF <- 10.02

(p1 <- ggplot(alpha_concurrent_Fs, aes(x=Fval)) +
  geom_histogram(fill="#277da1",color="black",linewidth=.5) +
  geom_vline(xintercept = realF, color = "#F4502C", linetype=2, linewidth=1.3) +
  labs(x = expression(italic(F) ~ " statistic (PIQ main effect)"), y="Count") +
  theme_light(base_size = 12, base_family = "sans") +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.major.y = element_line(color = alpha("grey60", 0.25), linewidth = 0.3),
        panel.grid.minor = element_blank(),
        axis.title.x = element_text(face = "bold", size = 14),
        axis.title.y = element_text(face = "bold", size = 14),
        axis.text = element_text(color = "grey15", family = "sans")))


## 2. Recurrent Alpha



alpha_rcrr_rois <- c("left_anterior-right_anterior", 
                     "right_anterior-right_anterior",
                     "medial_anterior-medial_anterior",
                     "medial_anterior-right_anterior",
                     "right_anterior-medial_anterior")

# Next line requires having the model EMTs loaded - otherwise input manually
real_t <- mean(emtrends_a.recurr[emtrends_a.recurr$p.value<0.05,]$t.ratio) 

(p2 <- alpha_recurrent_emts %>% 
    filter(ROI_pair %in% alpha_rcrr_rois) %>% 
    group_by(surr) %>% 
    summarise(t = mean(t), .groups = "drop") %>% 
    ggplot(aes(x=t)) +
    geom_histogram(fill="#277da1",color="black",linewidth=.5, bins = 33) +
    geom_vline(xintercept = real_t, color = "#F4502C", linetype=2, linewidth=1.3) +
    labs(x = expression(italic(t) ~ " ratio (PIQ estimated marginal trends)"), y="") +
    theme_light(base_size = 12, base_family = "sans") +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(color = alpha("grey60", 0.25), linewidth = 0.3),
          panel.grid.minor = element_blank(),
          axis.title.x = element_text(face = "bold", size = 14),
          axis.title.y = element_text(face = "bold", size = 14),
          axis.text = element_text(color = "grey15", family = "sans")))

## 3. Concurrent Theta

theta_sync_rois <- c("medial_central-right_anterior")

# Next line requires having the model EMTs loaded - otherwise input manually
real_t <- mean(emtrends_t.sync[emtrends_t.sync$p.value<0.05,]$t.ratio)

(p3 <- theta_concurrent_emts %>% 
    filter(ROI_pair %in% theta_sync_rois) %>% 
    ggplot(aes(x=t)) +
    geom_histogram(fill="#277da1",color="black",linewidth=.5) +
    geom_vline(xintercept = real_t, color = "#F4502C", linetype=2, linewidth=1.3) +
    labs(x = expression(italic(t) ~ " ratio (PIQ estimated marginal trends)"), y="") +
    theme_light(base_size = 12, base_family = "sans") +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(color = alpha("grey60", 0.25), linewidth = 0.3),
          panel.grid.minor = element_blank(),
          axis.title.x = element_text(face = "bold", size = 14),
          axis.title.y = element_text(face = "bold", size = 14),
          axis.text = element_text(color = "grey15", family = "sans")))

# pvalue: sum(theta_concurrent_emts[theta_concurrent_emts$ROI_pair %in% theta_sync_rois,]$t>real_t)/200


## 4. Recurrent Theta

theta_recurrent_rois <- c("left_temporal-medial_anterior")

# Next line requires having the model EMTs loaded - otherwise input manually
real_t <- mean(emtrends_t.rcrr[emtrends_t.rcrr$p.value<0.05,]$t.ratio)

(p4 <- theta_recurrent_emts %>% 
    filter(ROI_pair %in% theta_recurrent_rois) %>% 
    ggplot(aes(x=t)) +
    geom_histogram(fill="#277da1",color="black",linewidth=.5) +
    geom_vline(xintercept = real_t, color = "#F4502C", linetype=2, linewidth=1.3) +
    labs(x = expression(italic(t) ~ " ratio (PIQ estimated marginal trends)"), y="") +
    theme_light(base_size = 12, base_family = "sans") +
    theme(panel.grid.major.x = element_blank(),
          panel.grid.major.y = element_line(color = alpha("grey60", 0.25), linewidth = 0.3),
          panel.grid.minor = element_blank(),
          axis.title.x = element_text(face = "bold", size = 14),
          axis.title.y = element_text(face = "bold", size = 14),
          axis.text = element_text(color = "grey15", family = "sans")))


