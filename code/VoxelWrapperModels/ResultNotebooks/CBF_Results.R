#' ---
#' title: "Multivariate Voxelwise `gam()` Results: CBF"
#' author: "Tinashe M. Tapera"
#' date: "2019-02-15"
#' ---

#+ setup
suppressPackageStartupMessages({
  library(tidyr)
  library(dplyr)
  library(knitr)
  library(ggplot2)
  library(magrittr)
  library(stringr)
  library(oro.nifti)
  library(purrr)
  library(RColorBrewer)
})

print(paste("Last Run:", format(Sys.time(), '%Y-%m-%d')))

#' # Summarising Results of the ISLA Voxelwise Models
#'
#' Here we visualise the results of the isla voxelwise models. These models were of the form:
#'
#' `Y ~ s(age) + s(age,by=sex) + sex + pcaslRelMeanRMSMotion`
#'
#' We compare the output of the models where `Y` is:
#
#' 1. Raw CBF
#' 2. Smoothed CBF with a smoothing kernel of 3mm
#' 3. Smoothed CBF with a smoothing kernel of 4mm
#' 4. ISLA CBF with a kernel radius of 3mm
#' 5. ISLA CBF with a kernel radius of 4mm.

#+ gather data
results_dir <- "/data/jux/BBL/projects/isla/results/VoxelWrapperModels/imco1"

rawcbf_dir <- file.path(results_dir, "raw_cbf")
smoothed3_dir <- file.path(results_dir, "rawSmoothedCBF_3")
smoothed4_dir <- file.path(results_dir, "rawSmoothedCBF_4")
isla3_dir <- file.path(results_dir, "cbf3")
isla4_dir <- file.path(results_dir, "cbf4")

images_df <- c(
  rawcbf_dir,
  smoothed3_dir,
  smoothed4_dir,
  isla3_dir,
  isla4_dir) %>%
  tibble(path = .) %>%
  group_by(path) %>%
  mutate(
    images_paths = map(
      .x = path,
      .f = list.files,
      pattern = "fdr",
      recursive = TRUE,
      full.names = TRUE)
  ) %>%
  unnest()
#'
#' Read in the Niftis and the mask
#'
#+ read in
images_df <- images_df %>%
  mutate(
    variable = str_extract(
      string = images_paths,
      pattern = "(?<=fdr_)(.*)(?=\\.nii)") %>%
        str_replace(pattern = "sage", "s(age)") %>%
        str_replace(pattern = "and", " by ") %>%
        str_replace(pattern = "\\.L", "") %>%
        str_replace(pattern = "2", ""),
    nifti = map(images_paths, readNIfTI, reorient = FALSE),
    Y = str_extract(string = path, pattern = "(?<=imco1/).*$")
)

mask <- "/data/jux/BBL/projects/isla/data/Masks/gm10perc_PcaslCoverageMask.nii.gz"
mask_img <- readNIfTI(mask)
maskdat <- img_data(mask_img)
#'
#' Below is a helper function to extract the data from a nifti and get the proportion of significant and non-significant voxels at $p < 0.05$. Then, we apply the function
#'

returnFDR <- function(nif, variable, mask = maskdat) {

  tempdat <- img_data(nif)
  tempdat <- tempdat[mask != 0]
  table(tempdat < 0.05) %>%
    data.frame() %>%
    mutate(Covariate = variable) %>%
    rename(Significant = Var1) %>%
    return()
}

results <- images_df %>%
  group_by(Y, variable) %>%
  mutate(results = list(map2_df(nifti, variable, returnFDR))) %>%
  ungroup() %>%
  select(Y,results) %>%
  unnest()
#'
#' Also, a helper function to help label the plot:
#'

y_names <- list(
  "cbf3" = "Y: ISLA CBF 3",
  "cbf4" = "Y: ISLA CBF 4",
  "raw_cbf" = "Y: Raw CBF",
  "rawSmoothedCBF_3" = "Y: Raw Smoothed CBF 3",
  "rawSmoothedCBF_4" = "Y: Raw Smoothed CBF 4"
)

my_labels <- function(variable, value){
  return(y_names[value])
}
#'
#' Now, plot:
#'

results %>%
  ggplot(aes(x = Covariate, y = Freq)) +
    geom_bar(aes(fill = Significant), stat = "identity") +
    theme_minimal() +
    labs(
      title = "Number of Significant Voxels Per Covariate",
      y = "Frequency of Voxels",
      subtitle = "FDR Corrected Voxelwise GAM",
      caption = "Model: Y~s(age)+s(age,by=sex)+sex+pcaslRelMeanRMSMotion") +
    theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
    scale_fill_brewer(palette = "Set1") +
    facet_wrap(~Y, labeller = my_labels)
