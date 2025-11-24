// ======= USER SETTINGS =======
stackDir = "C:/path/to/input/folders/"; // Path to the folders containing image time-sequences that will be converted to stacks
metadataFile = "C:/path/to/metadata/overview/filename.csv"; // CSV file containing the names of the folders in stackDir, along with other essential information
outputFile = "C:/path/to/output/filename.csv"; // Outputs the metadataFile including the calculated variances

// ======= MACRO START =======
setBatchMode(true);

// Read metadata table
metadata = File.openAsString(metadataFile);
lines = split(metadata, "\n");
header = split(lines[0], ",");

// Find 'mean_variance' and 'image_name' columns
meanVarCol = -1;
nameCol = -1;
for (i = 0; i < lengthOf(header); i++) {
    if (trim(header[i]) == "mean_variance") meanVarCol = i;
    if (trim(header[i]) == "image_name") nameCol = i;
}

// Ensure header has mean_variance column
if (meanVarCol == -1) {
    meanVarCol = lengthOf(header);
    headerLine = lines[0] + ",mean_variance";
} else {
    headerLine = lines[0];
}
newMetadata = headerLine + "\n";

// Function to get image files in folder (non-recursive)
function getImageFiles(folderPath) {
    files = getFileList(folderPath);
    images = newArray();
    for (i = 0; i < lengthOf(files); i++) {
        if (!File.isDirectory(folderPath + "/" + files[i]) &&
            (endsWith(files[i], ".tif") || endsWith(files[i], ".tiff") || endsWith(files[i], ".jpg") || endsWith(files[i], ".png"))) {
            images = Array.concat(images, folderPath + "/" + files[i]);
        }
    }
    return images;
}

// Process each stack folder
for (i = 1; i < lengthOf(lines); i++) {
    if (trim(lines[i]) == "") continue;
    fields = split(lines[i], ",");
    fileName = trim(fields[nameCol]);
    stackPath = stackDir + fileName; 

    images = getImageFiles(stackPath);

    if (lengthOf(images) == 0) {
        print("No images found in: " + stackPath);
        while (lengthOf(fields) <= meanVarCol)
            fields = Array.concat(fields, "");
        fields[meanVarCol] = "No images";

        rowLine = fields[0];
        for (j = 1; j < lengthOf(fields); j++)
            rowLine = rowLine + "," + fields[j];
        newMetadata = newMetadata + rowLine + "\n";
        continue;
    }

    // Open as 16-bit virtual stack
	File.openSequence(stackPath + "/", "virtual bitdepth=16");
	rename("stack");
	// Check if the window "stack" exists
	if (!isOpen("stack")) {
	    print("Failed to open stack: " + stackPath);
	    fields[meanVarCol] = "Open failed";
	
	    rowLine = fields[0];
	    for (j = 1; j < lengthOf(fields); j++)
	        rowLine = rowLine + "," + fields[j];
	    newMetadata = newMetadata + rowLine + "\n";
	    continue;
	}

    // Make substack safely
    run("Make Substack...", "slices=1-250");

    // Center crop 1000x500
    w = getWidth();
    h = getHeight();
    x = (w - 1000) / 2;
    y = (h - 500) / 2;
    makeRectangle(x, y, 1000, 500);
    run("Crop");

    // Pre-process
    run("Subtract Background...", "rolling=5 light sliding stack");
    run("Median...", "radius=3 stack");

    // Z Project and square
    run("Z Project...", "projection=[Standard Deviation]");
    projTitle = getTitle();
    run("Square");

    // Measure mean variance
    run("Set Measurements...", "mean display redirect=None decimal=4");
    run("Measure");
    if (nResults() > 0) {
        meanVar = getResult("Mean", 0);
    } else {
        meanVar = "NA";
    }

    // Close results and intermediate images
    if (isOpen("Results")) close("Results");
    if (isOpen(projTitle)) close(projTitle);
    close(); // closes the stack window

    // Store result
    while (lengthOf(fields) <= meanVarCol)
        fields = Array.concat(fields, "");
    fields[meanVarCol] = meanVar;

    // Build row string
    rowLine = fields[0];
    for (j = 1; j < lengthOf(fields); j++)
        rowLine = rowLine + "," + fields[j];
    newMetadata = newMetadata + rowLine + "\n";

    print(fileName + " processed. Variance: " + meanVar);
}

// Save updated metadata
File.saveString(newMetadata, outputFile);
setBatchMode(false);
print("Processing complete. Results saved to: " + outputFile);
