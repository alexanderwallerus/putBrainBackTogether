# putBrainBackTogether

## Align 2D scan (=image) files and create a 3D maximum projection model easily

Simply place a series of RGB image files in the "slices" folder (i.e. S0.png, S1.png, S2.png, S3.png...) and run the program.
The images can be taken from tissue slices with a fluorescence microscope tilescan, or from any other data that consists of 2D images taken throughout a 3D object.
In the program you can simply drag and drop and rotate and invert the 2D slices on top of another to quickly align them.

By default the slices' z resolution defines all 3 voxel dimensions (i.e. 70x70x70um voxels), however by increasing the subDiv parameter you can subdivide each voxel in x and y for achieving a higher x y resolution (i.e. 35x35x70um or an even higher resolution)

Please be aware that this program can become very memory expensive with large data.


## Future plans/TODO:
* add a transformation parameter for the number of slices skipped from the last slice and thus allow a model which had i.e. only every 4th slice imaged.

* add a parameter for easily setting any custom slice thicknesses other than 70um.

* learn how to use shaders and rework this code to run more efficiently, maybe as a point cloud... As it is it needs a large amount of RAM
