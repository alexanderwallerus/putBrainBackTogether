# putBrainBackTogether

## Align 2D scan (=image) files and create a 3D maximum projection model easily

Simply place a series of RGB image files in the "slices" folder (i.e. S0.png, S1.png, S2.png, S3.png...) and run the program.
The images can be taken from tissue slices with a fluorescence microscope tilescan, or from any other data that consists of 2D images taken throughout a 3D object.
In the program you can simply drag and drop and rotate and invert the 2D slices on top of another to quickly align them.

You can define your experiment images' umPerPixel and slice thickness at the beginning of the code. By default the thickness of your slices will determine the resolution of the point cloud (i.e. 70um slices will create points of 70x70x70um), however by increasing the subDiv parameter in the program you can subdivide each point in x and y for achieving a higher x y resolution (i.e. 35x35x70um or an even higher resolution)

As alternative rendering you can replace the point cloud with voxels or PImages by changing the renderMode variable. Please be aware that the point cloud and voxels can become very memory expensive with a high subdivision modifier on large data.

The used 3D brain model is a modified version of the wholebrain_mesh from the the [Allen Reference Atlas](https://scalablebrainatlas.incf.org/mouse/ABA_v3).
I manually cleaned up the model's internal structures and smoothed out the edges they formed to allow for a clean outline projection.
> Lein ES, Hawrylycz MJ, Ao N, et al. (2007) "Genome-wide atlas of gene expression in the adult mouse brain." Nature 445(7124):168-76. [doi 10.1038/nature05453]

## Future plans/TODO:
* Add an alternative rat brain outline

* Look into the doability of ray tracing this data