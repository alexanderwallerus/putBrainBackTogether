//code by Alexander Wallerus
//MIT License

//This code will allow you to easily align scan slices from image files by dragging
//and dropping and rotating them on top of another. It will then create a simple
//3D maximum projection of all aligned slices that can be rotated and moved around.

//If you intend to use this code for your project you may have to adjust the
//umPerPixel and sliceThickness variables to fit your experiment.
//Also please note that the voxel and point cloud render modes are very RAM
//expensive and thus may not be viable for all projects.
//Setting subDiv to a number >1 ("D"-key) will subdivide each voxel/point in x and y
//whilst keeping the thickness in z unaffected. This will increase the 
//visualization resolution accordingly but is also additionally memory expensive.

import peasy.PeasyCam;
PeasyCam cam;

//Please adjust this block of variables for your project:
//Set the umPerPixel to the resolution of your microscope scan
float umPerPixel = 0.908;
//Set the sliceThickness to the thickness of your slices in um
float sliceThickness = 70;
//Set zDir to +1 or -1 to build slices + or - into the z axis
int zDir = 1;
//Set renderMode to 0, 1, or 2 for 0: voxels, 1: point cloud, 2: PImage rendering
int renderMode = 1;       
//The point cloud is more efficient than voxels allowing higher detail visualization.
//The PImage mode does provide the highest resolution, but no matter how densely
//the PImage layers are packed, some viewing angles will be able to see between them.
//It might be a good idea to write a custom shader for the 3D view in the future.

String[] fileNames;
PImage[] slices;
Transformation[] trans;
int currentSlice;
boolean showRoi;
boolean showOverlay;
boolean show2D;           //this boolean is turned false for 3D projection view
float rotIncrement = 0.01;
int edgeLength;           //needed for PImage render mode scaling
int subDiv;   //each voxel/point will be split into sq(subDiv) new ones: (1, 4, 9...)
              //1 = 70x70x70um voxels (default), 2 = 35umx35umx70um... 
              
color[][][] voxCols;
PShape voxels[];
BrainTrans brainTrans;   //transformation for the brain outline model
PShape mouseBrain;
PShader edges;
boolean showOutline = true;
boolean alignOutline = false;

void setup(){
  size(1000, 1000, P3D);
  cam = new PeasyCam(this, 400);
  hint(DISABLE_DEPTH_SORT);
  hint(DISABLE_DEPTH_TEST);
  hint(DISABLE_DEPTH_MASK);
  if(renderMode == 1){
    hint(ENABLE_STROKE_PERSPECTIVE);
  }
  
  //increase the zFar clipping plane from default to 20x
  float cameraZ = (height/2.0) / tan(PI*60.0/360.0);
  perspective(PI/3.0, width/height, cameraZ/10.0, cameraZ*10.0 *20);
    
  show2D = true;
  showOverlay = true;
  showRoi = false;
  subDiv = 1;
  
  String path = sketchPath();
  fileNames = listFileNames(path + "/slices");
  fileNames = subset(fileNames, 1);    //remove the empty .gitkeep file from the array
  println("the following files exist:");
  printArray(fileNames);
  
  slices = new PImage[fileNames.length];
  
  //uncomment the following line for quickly loading only 3 slices during debugging
  //slices = new PImage[3];
  
  float origImgMaxImgDim = findMaxImgDim(path);  
  //i.e.13014.0
  
  //original scans were done with a 5x objective, 0.908um/pixel, 70um thickness
  //and are up to 13014 pixels wide => slice thickness will be the major resolution
  //limit for most viewing angles. 
  //Scale images down onto a width=height=1000 image, a more reasonable image
  //size but still enough xy points to support subdividing 70um points in xy for a 
  //higher xy resolution if needed.
  //Math: origImgWidth * x = 1000 => x = 1000/origImgWidth
  float scaling = 1000.0/origImgMaxImgDim;
  //multiply image width and height with this factor and divide umPerPixel by it
  umPerPixel = umPerPixel / scaling;
  println("um per pixel on 1000x1000 pixel images: " + umPerPixel);   //11.816711
  
  for(int i=0; i<slices.length; i++){
    //.pngs are compressed => even if a slice image is "only" 75MB, it will be 
    //hundreds of MB in memory due to having to keep all uncompressed pixel values.
    //=> resizing images can help with RAM usage.
    slices[i] = loadImage(path + "/slices/" + fileNames[i]);
    slices[i].resize(int(slices[i].width  * scaling),
                     int(slices[i].height * scaling));
    println("successfully loaded slice: " + fileNames[i]);
  }

  trans = new Transformation[slices.length];
  //start with all transformations being 0
  for(int i=0; i<trans.length; i++){
    trans[i] = new Transformation();
    trans[i].sliceName = fileNames[i];
  }
  currentSlice = 0;
  
  voxels = new PShape[slices.length];
  //trying to put all subdivided points into a single shape can cause
  //java.lang.ArrayIndexOutOfBoundsException: 67108864 => use a group for each slice
  for(int i=0; i<voxels.length; i++){
    voxels[i] = createShape(GROUP);
  }
  
  //add a single test voxel with this code block for debugging:
  //  noStroke();
  //  PShape vox = createShape(BOX, 10, 10, 10);
  //  vox.setFill(color(int(random(256)), int(random(256)), int(random(256))));
  //voxels.addChild(vox);
  
  //wholebrain_mesh from https://scalablebrainatlas.incf.org/mouse/ABA_v3
  //I slightly modified the model by manually cleaning up internal structures and
  //smoothing out the edges they formed to allow for a clean outline projection.
  mouseBrain = loadShape("allenBrainCleaned.obj");
  //shader from the official processing examples: Topics => Shaders => EdgeFilter
  edges = loadShader("edges.glsl");
  brainTrans = new BrainTrans();
}

void draw(){
  if(show2D){
    blendMode(NORMAL);
    cam.beginHUD();
      background(0);
      pushMatrix();
        imageMode(CENTER);
        if(slices[currentSlice] != null){
          translate(slices[currentSlice].width/2, slices[currentSlice].height/2);
          translate(trans[currentSlice].xy.x, trans[currentSlice].xy.y);
          rotate(trans[currentSlice].rotation);
          image(slices[currentSlice], 0, 0);
        }
      popMatrix();
      drawOverlay();
    cam.endHUD();
  } else {
    background(0);
    blendMode(LIGHTEST);
    if(showOutline){
      lights();   //without light the surface of the 3d object won't be visible
                  //it would function as only an outline filter.
      pushMatrix();
        translate(brainTrans.xyz.x * subDiv, brainTrans.xyz.y * subDiv, 
                  brainTrans.xyz.z * subDiv);
        //use YZX (!) => user can drag YZ rotations to any spherical coordinate and
        //then roll the outline around its relative x to achieve any 3D rotation
        rotateY(brainTrans.xyzRot.y);
        rotateZ(brainTrans.xyzRot.z);
        rotateX(brainTrans.xyzRot.x);
        scale(brainTrans.scale * subDiv);
        
        shape(mouseBrain);
      popMatrix();
      filter(edges);   //everything drawn so far will be rendered with the filter
      noLights();      //afterwards show voxels/point cloud with pure colors
      if(keyPressed){
        moveBrainOutline();
      }
    }
    try{
      for(PShape s : voxels){
        shape(s);
      }
    } catch(Exception e){
      println(e);
      exit();
    }
    if(renderMode == 2){
      float skippedSlicesOffset = 0;
      for(int i=0; i<slices.length; i++){
        skippedSlicesOffset += trans[i].slicesSkippedFromLast;
        float currentZ = (-zDir*(i+skippedSlicesOffset) *subDiv + 
                           zDir*slices.length/2 *subDiv) *10;
        float nextZ;
        if(i+1 < trans.length){
          nextZ = (-zDir*(i+1+skippedSlicesOffset+trans[i+1].slicesSkippedFromLast) 
                    *subDiv + 
                    zDir*slices.length/2 *subDiv) *10;
        } else {
          nextZ = (-zDir*(i+1+skippedSlicesOffset) *subDiv + 
                    zDir*slices.length/2 *subDiv) *10;
        }
        for(float f=0; f<1; f+=0.03){
          float imgZ = lerp(currentZ, nextZ, f);
          pushMatrix();
            translate(0, 0, imgZ);
            image(slices[i], 0, 0, edgeLength*10, edgeLength*10);
          popMatrix();
        }
      }
    }
    cam.beginHUD();
      if(alignOutline){
        textSize(20);
        textAlign(CENTER);
        fill(255, 0, 0);
        text("Outline Aligning Mode", width/2, 30);
      }
    cam.endHUD();
  }
}

void createVolume(){
  //println(umPerPixel);                        //11.816711
  //If our depth is i.e. 70um we would like a 70x70x70um voxel/point as default.
  //=> we want 1 pixel to be 70um (or i.e. 30 um if we have 30um slices)
  //Math: 11.816711u/pix * scaling = 70u/pix => scaling = 70/11.816711 = 5.923814
  float targetScaling = sliceThickness / umPerPixel;
  //if the um/pix doubles, the image width halves. =>
  //divide the image width (=image height=1000) through this same value
  println("rescaling pixels into points by factor: " + 1/targetScaling);   //0.168810
  int newImgWidth = int(round(1000 / targetScaling));
  //168.8101571 rounded to 169 => a 169x169 pix image
  //This rounding (from 168.8101571 to 169) creates a very small inaccuracy in the xy
  //extent of all points that could be eliminated through point placement and size in
  //the future.
  println("volume slice resolution without subdivisions: " + newImgWidth + "*" + 
          newImgWidth + " points/voxels");
  if(subDiv != 1){
    println("subdivididing each point into: " + int(sq(subDiv)) + " points in x/y");
    newImgWidth *= subDiv;            //i.e. 2x the newImgwidth => 4x the voxels
    println("the maximum volume dimension is " + newImgWidth + " points long.");
    println("please note that a maxium dimension of over 1000 points is not " +
            "reccomended");
  }
  voxCols = new color[newImgWidth][newImgWidth][slices.length];
  
  int skippedSlicesOffset = 0;  
  //amount of z offset from skipped slices existing by this slice
  for(int i=0; i<slices.length; i++){
    //redraw the image with the same transformation as shown in 2D in a PGraphics
    PGraphics current = createGraphics(1000, 1000);
    current.beginDraw();    current.endDraw();
    current.beginDraw();
      current.push(); 
        current.imageMode(CENTER);
        current.translate(slices[i].width/2, slices[i].height/2);
        current.translate(trans[i].xy.x, trans[i].xy.y);
        current.rotate(trans[i].rotation);
        current.image(slices[i], 0, 0);
      current.pop();
      //now make everything outside the region of interest black
      if(showRoi){
        current.fill(0);  current.noStroke();
        current.rectMode(CORNERS);
        current.rect(0, 0, width, min(trans[i].roi[0].y, trans[i].roi[1].y));
        current.rect(0, 0, min(trans[i].roi[0].x, trans[i].roi[1].x), height);
        current.rect(max(trans[i].roi[0].x, trans[i].roi[1].x), 0, width, height);
        current.rect(0, max(trans[i].roi[0].y, trans[i].roi[1].y), width, height);
      }
    current.endDraw();
    
    if(renderMode == 2){
      subDiv = 1;    
      //subDivs don't make sense in this mode, but would affect the outline scale
      edgeLength = voxCols.length;
      //take the aligned images
      slices[i] = current.copy();
       //don't fill in the shape
      continue; 
    }
    
    //resize the drawn image to the correct size => PGraphics needs to become an image
    PImage cur = current.copy();
    cur.resize(newImgWidth, newImgWidth);
    
    //fill the voxCols array
    cur.loadPixels();    
    for(int y = 0; y<cur.height; y++){
      for(int x = 0; x<cur.width; x++){
        int idx = y*cur.width + x;
        voxCols[x][y][i] = color(cur.pixels[idx]);
      }
    }
    cur.updatePixels();
    
    //free some memory by overwriting the large slices images that won't be needed
    //for 3D visualization anymore, since all data is stored in voxCols.
    //finalyze() may be a better way to do this...
    slices[i] = null;
    current = null;
    cur = null;
    System.gc();  //force the system to garbage collect now
    println("Free memory: " + Runtime.getRuntime().freeMemory());
    
    skippedSlicesOffset += trans[i].slicesSkippedFromLast;
    if(renderMode == 0){
      for(int y = 0; y<voxCols[0].length; y++){    //image height
        for(int x = 0; x<voxCols.length; x++){     //image width
          noStroke();
          PShape vox = createShape(BOX, 10, 10, 10*subDiv);
          vox.setFill(voxCols[x][y][i]);
          //default subDiv==1, no subdivisions
          vox.translate((x - voxCols.length/2)*10, (y - voxCols[0].length/2)*10,
                        (-zDir*(i+skippedSlicesOffset) *subDiv + 
                         zDir*voxCols[0][0].length/2 *subDiv)*10);
          voxels[i].addChild(vox);
        }
      }
      println("created slice " + i + " voxel data");
    } else {
      PShape points = createShape();
      points.beginShape(POINTS);
      for(int y = 0; y<voxCols[0].length; y++){ //image height
        for(int x = 0; x<voxCols.length; x++){  //image width
          for(int j=0; j<subDiv; j++){    //if subDiv > 1 copy points offset in depth
            points.strokeWeight(12);      //a bit over the ideal 10, to better fill 
            points.noFill();              //out the space with points
            points.stroke(voxCols[x][y][i]);
            points.vertex((x - voxCols.length/2)*10, (y - voxCols[0].length/2)*10,
                          (-zDir*(i+skippedSlicesOffset) *subDiv + 
                            zDir*voxCols[0][0].length/2 *subDiv)*10
                            + 10*j);
          }
        }
      }
      println("created slice " + i + " point data");
      points.endShape();
      voxels[i].addChild(points);
    }
  }
  voxCols = null;
  System.gc();
  println("Free memory: " + Runtime.getRuntime().freeMemory());
}

class Transformation{
  String sliceName;
  PVector xy;
  float rotation;
  boolean mirrored;
  PVector[] roi;
  int slicesSkippedFromLast;
  
  Transformation(){
    sliceName = "";
    rotation = 0;
    xy = new PVector(0, 0);
    mirrored = false;
    roi = new PVector[]{new PVector(0, 0), new PVector(0, 0)};
    slicesSkippedFromLast = 0;
  }
}

class BrainTrans{
  PVector xyz, xyzRot;
  float scale;
  
  BrainTrans(){
    xyz =  new PVector();
    xyzRot = new PVector();
    scale = 1.0;
  }
}

void drawOverlay(){
if(showRoi){
  pushStyle();
    noFill();  strokeWeight(1);  stroke(255, 0, 0);
    rectMode(CORNERS);
    rect(trans[currentSlice].roi[0].x, trans[currentSlice].roi[0].y, 
         trans[currentSlice].roi[1].x, trans[currentSlice].roi[1].y);
  popStyle();
  }
  if(showOverlay){
    String[] leftLines = {
      "slice: " + trans[currentSlice].sliceName,
      "x: " + trans[currentSlice].xy.x,
      "y: " + trans[currentSlice].xy.y,
      "rotation: " + trans[currentSlice].rotation,
      "mirrored: " + trans[currentSlice].mirrored,
      "slices skipped from last: " + trans[currentSlice].slicesSkippedFromLast,
      "point subdivision modifier: " + subDiv};
    String[] rightLines = {
      "Controls:",
      "Move slice: DRAG LEFT MOUSE",
      "Rotate slice: SHIFT + WHEEL",
      "Flip slice: F",
      "Change slice: WHEEL",
      "Create region of interest: DRAG RIGHT MOUSE",
      "Toggle region of interest visible and active: R",
      "Load previously saved transformations: L",
      "Save current transformations: S",
      "Create 3D shape data and view swap to 3D: C",
      "Change slices skipped from last: [ ]",
      "Toggle Overlay on/off: O",
      "SubDivide voxels/points: D",
      "Toggle Brain Outline (in 3D): O",
      "Move Outline X/Y/Z (in 3D): DG/ET/RF",
      "Toggle Outline Rotation mode (in 3D): A",
      "Rotate/Roll/Scale outline (in 3D after \"A\"):",
      "DRAG LEFT/RIGHT MOUSE/WHEEL",
      "Save/Load Outline alignment (in 3D): S/L"};
    for(int i=0; i<leftLines.length; i++){
      textAlign(LEFT);
      text(leftLines[i], 10, 20 + (i*20));
    }
    for(int i=0; i<rightLines.length; i++){
      textAlign(RIGHT);
      text(rightLines[i], 980, 20 + (i*20));
    }
  }
}     
