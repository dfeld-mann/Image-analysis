// ======= USER SETTINGS =======
inputDir = "C:/path/to/input/images/"; // Path to the images 
metadataFile = "C:/path/to/metadata/overview/filename.csv"; // CSV file containing the names of the images in inputDir, along with other essential information
outputFile = "C:/path/to/output/filename.csv"; // Outputs the metadataFile including the calculated total cell areas per images

// ======= MACRO START =======
setBatchMode(true);

// Read metadata table ---
metadata = File.openAsString(metadataFile);
lines = split(metadata, "\n");
header = split(lines[0], ",");

// Find column indices
pairCol = -1;
cellCountCol = -1;
cellAreaCol = -1;
strainCol = -1;
for (i = 0; i < lengthOf(header); i++) {
    if (indexOf(header[i], "pair_ID") >= 0) pairCol = i;
    if (indexOf(header[i], "cell_count") >= 0) cellCountCol = i;
    if (indexOf(header[i], "total_cell_area") >= 0) cellAreaCol = i;
    if (indexOf(header[i], "strain") >= 0) strainCol = i;
}

// If 'cell_count' column missing, add it
if (cellCountCol == -1) {
    cellCountCol = lengthOf(header);
    headerLine = header[0];
    for (i = 1; i < lengthOf(header); i++)
        headerLine = headerLine + "," + header[i];
    headerLine = headerLine + ",cell_count";
} 
else {
    headerLine = header[0];
    for (i = 1; i < lengthOf(header); i++)
        headerLine = headerLine + "," + header[i];
}

// Initialize new metadata string
newMetadata = headerLine + "\n";

// Gather unique pair_IDs
pairIDs = newArray();
for (i = 1; i < lengthOf(lines); i++) {
    if (trim(lines[i]) == "") continue;
    fields = split(lines[i], ",");
    pid = trim(fields[pairCol]);
    if (pid != "") {
        exists = false;
        for (p = 0; p < lengthOf(pairIDs); p++) {
            if (pairIDs[p] == pid) exists = true;
        }
        if (!exists)
            pairIDs = Array.concat(pairIDs, newArray(pid));
    }
}

print("Found " + lengthOf(pairIDs) + " unique pair_IDs");

// Process each pair_ID
for (p = 0; p < lengthOf(pairIDs); p++) {
    pid = pairIDs[p];
    print("\nProcessing pair_ID: " + pid);

    // Find the two rows for this pair and process them immediately
    countImages = 0;
    for (i = 1; i < lengthOf(lines); i++) {
        if (trim(lines[i]) == "") continue;
        fields = split(lines[i], ",");
        if (trim(fields[pairCol]) != pid) continue;

        filename = trim(fields[0]);
        imagePath = inputDir + filename + ".tif";

        if (!File.exists(imagePath)) {
            print("Missing file: " + imagePath);
            while (lengthOf(fields) <= cellCountCol)
                fields = Array.concat(fields, "");
            fields[cellCountCol] = "Not found";

            // Append immediately
            rowLine = fields[0];
            for (k = 1; k < lengthOf(fields); k++)
                rowLine = rowLine + "," + fields[k];
            newMetadata = newMetadata + rowLine + "\n";
            continue;
        }

        // Open and process image
        open(imagePath);
        run("32-bit");

        // If first image of the pair, open second image and make stack
        if (countImages == 0) {
            firstImage = getTitle();
            countImages++;
            continue;
        } else if (countImages == 1) {
            secondImage = getTitle();
            run("Images to Stack", "use");
            rename("MyStackName");
            run("32-bit");
            
            // Crop 1000x1000
            w = getWidth();
            h = getHeight();
            x = (w - 1000) / 2;
            y = (h - 1000) / 2;
            makeRectangle(x, y, 1000, 1000);
            run("Crop");

            // Background subtraction again for the stack
            run("Subtract Background...", "rolling=5 light sliding stack");
                 
            saveDir = "C:/Users/dfeld/OneDrive/Documents/Master Nanobiology/Internship/9. Results/Binder assays/Analysis/aligned_stacks/";
			File.makeDirectory(saveDir); // create folder if it doesn't exist
			stackName = "Stack_" + pid + ".tif";
			savePath = saveDir + stackName;
			saveAs("Tiff", savePath);
			print("Saved aligned stack for pair_ID " + pid + " to: " + savePath);

            // Split stack
            run("Stack to Images");
            list = getList("image.titles");
            if (lengthOf(list) != 2) print("Stack split did not produce 2 images for pair_ID " + pid);

            // Process both images in order
            for (j = 0; j < 2; j++) {
                selectWindow(list[j]);

                setAutoThreshold("Default dark");
                run("Convert to Mask");
                run("Invert");

                // Determine size range
                strain = "";
                if (strainCol >= 0 && strainCol < lengthOf(fields))
                    strain = trim(fields[strainCol]);
                if (strain == "E. coli") sizeRange = "1-25";
                else if (strain == "B. subtilis") sizeRange = "2-65";

                run("Set Measurements...", "area redirect=None decimal=3");
                cmd = "size=" + sizeRange + " circularity=0.00-1.00 show=Nothing clear summarize";
                run("Analyze Particles...", cmd);

                n = nResults;
                totalArea = getResult("Total Area", 0, "Summary");
                close("Results");
                close("Summary");
                close();

                // Identify the corresponding metadata entry based on image name
				imgName = replace(list[j], ".tif", "");
				idx = -1;
				for (i = 1; i < lengthOf(lines); i++) {
				    if (startsWith(trim(lines[i]), imgName)) {
				        idx = i;
				        break;
				    }
				}
				
				if (idx == -1) {
				    print("Could not find metadata entry for " + imgName);
				    continue;
				}
				
				// Store result immediately
				fields = split(lines[idx], ",");
				while (lengthOf(fields) <= cellCountCol)
				    fields = Array.concat(fields, "");
				fields[cellCountCol] = n;
				fields[cellAreaCol] = totalArea;
				
				// Rebuild the line
				rowLine = fields[0];
				for (k = 1; k < lengthOf(fields); k++)
				    rowLine = rowLine + "," + fields[k];
				lines[idx] = rowLine;
				
				print("Pair_ID " + pid + ", image " + j + " (" + imgName + ") counted " + n + " cells and cell area is " + totalArea);
            }

            countImages = 0; // reset for next pair
        }
    }
}

// Save updated metadata
newMetadata = headerLine + "\n";
for (i = 1; i < lengthOf(lines); i++) {
    if (trim(lines[i]) != "")
        newMetadata = newMetadata + lines[i] + "\n";
}

File.saveString(newMetadata, outputFile);
setBatchMode(false);
print("\nProcessing complete. Results saved to: " + outputFile);
