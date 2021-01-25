# putBrainBackTogether

## Align 2D scan (=image) files and create a 3D maximum projection model easily

Simply place a series of RGB image files in the "slices" folder (i.e. S0.png, S1.png, S2.png, S3.png...) and run the program.
The images can be taken from tissue slices with a fluorescence microscope tilescan, or from any other data that consists of 2D images taken throughout a 3D object.
In the program you can simply drag and drop and rotate and invert the 2D slices on top of another to quickly align them.

By default the slices' z resolution defines all 3 voxel dimensions (i.e. 70x70x70um voxels), however by increasing the subDiv parameter you can subdivide each voxel in x and y for achieving a higher x y resolution (i.e. 35x35x70um or an even higher resolution)

Voxels are by default replaced with a more memory efficient point cloud to allow for higher detail visualization. Alternatively voxels can still be used by setting pointCloud = false;

Please be aware that this program can become very memory expensive with a high subdivision modifiers on large data.

The used 3D brain model is a modified version of the wholebrain_mesh from the the Allen Reference Atlas at https://scalablebrainatlas.incf.org/mouse/ABA_v3.
> Lein ES, Hawrylycz MJ, Ao N, et al. (2007) "Genome-wide atlas of gene expression in the adult mouse brain." Nature 445(7124):168-76. [doi 10.1038/nature05453]
I manually cleaned up the model's internal structures and smoothed out the edges they formed to allow for a clean outline projection.

## Future plans/TODO:
* add a parameter for easily setting any custom slice thicknesses other than 70um.

* add a function to create an increased detail image from the current 3D perspective.
For this purpose render each slice 3D data individually at a higher subdivision modifier into an image from the same perspective, then combine all images into a new maximum projection.