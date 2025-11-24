# ImageJ Macros used in internship report
ImageJ Macro Language scripts for automatically calculating the total cell area from images taken on drum-free graphene chips, in addition to the mean variance from time-sequences.

## Contents
- total_cell_area.ijm — Preprocessing and total cell area calculation of before and after images (before/after stacks are saved to verify alignment)
- mean_variance.ijm — Preprocessing and calculation of mean variance per total cell area

## Usage
Open in ImageJ/Fiji and run via Plugins > Macros > Run.
You need to update the input/output paths.
The following files/folders are required:

### For total cell area calculation
- CSV/Excel file containing the names of the image/video files in one column, in addition to other information (bacterial species, number of resuspensions, date, etc.)
- Folder containing the images

### For mean variance per total cell area calculation
- The output CSV file from total_cell_area.ijm, which is the input CSV/Excel file used for total_cell_area.ijm, but with a column containing the total cell areas per image (Videos and images are recorded on the same location on the chip)
- Folder contanining folders of image-time sequences generated from mp4 videos using FFmpeg. The videos (and thus folders) have the same name as the corresponding images
