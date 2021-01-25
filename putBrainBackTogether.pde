//code by Alexander Wallerus
//MIT License

//This code will allow you to easily align scan slices from image files by dragging
//and dropping and rotating them on top of another. It will then create a simple
//3D maximum projection of all aligned slices that can be rotated and moved around.

//If you intend to use this code for your project you may have to change it to
//fit your slice thickness/magnification parameters. It is also very RAM expensive
//and thus may not be viable for projects with interest in creating a volume view of 
//a large area at a high resolution.
//Setting subDiv to a number >1 will subdivide each voxel in x and y whilst keeping
//its z (given by the slice thickness) unaffected. This will increase the 
//visualization resolution accordingly but is also additionally memory expensive.

import peasy.PeasyCam;
PeasyCam cam;

String[] fileNames;
PImage[] slices;
Transformation[] trans;
int currentSlice;

float scaling;
float umPerPixel = 0.908;

boolean provideMaxImgDim = false;  //false = this will overwrite origImgMaxImgDim 
float origImgMaxImgDim = 13014.0;  //using .png file metadata

int subDiv;      //each voxel will be split into sq(subDiv) new voxels: (1, 4, 9...)
                 //1 = 70x70x70um voxels (default), 2 = 35umx35umx70um... 
boolean showRoi;
boolean showOverlay;
boolean show2D;           //this boolean is turned false for 3D projection view
float rotIncrement = 0.01;

color[][][] voxCols;
PShape voxels[];
int zDir = +1;            //set to +1 or -1 to build slices + or - into the z axis

boolean pointCloud = true;    
//a pointcloud is more efficient than voxels allowing higher detail visualization

BrainTrans brainTrans;   //transformation for the brain outline model
PShape mouseBrain;
PShader edges;
boolean showOutline = true;

void setup(){
  size(1000, 1000, P3D);
  cam = new PeasyCam(this, 400);
  hint(DISABLE_DEPTH_SORT);
  hint(DISABLE_DEPTH_TEST);
  hint(DISABLE_DEPTH_MASK);
  if(pointCloud){
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
  
  if(!provideMaxImgDim){
    origImgMaxImgDim = findMaxImgDim(path);
  }    
  
  //original scans were done with a 5x objective, 0.908um/pixel, 70um thickness
  //and are up to 13014 pixels wide => slice thickness will be the major resolution
  //limit. 
  //Scale images down onto a width=height=1000 image, a more reasonable image
  //size but still enough xy points to support subdividing 70um voxels in xy for a 
  //higher xy resolution if needed.
  //origImgWidth * x = 1000 => x = 1000/origImgWidth
  scaling = 1000.0/origImgMaxImgDim;
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
  //java.lang.ArrayIndexOutOfBoundsException: 67108864
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
  mouseBrain = loadShape("allenBrainHollowSmoothed.obj");
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
      if(showRoi){
        pushStyle();
          noFill();  strokeWeight(1);  stroke(255, 0, 0);
          rectMode(CORNERS);
          rect(trans[currentSlice].roi[0].x, trans[currentSlice].roi[0].y, 
               trans[currentSlice].roi[1].x, trans[currentSlice].roi[1].y);
        popStyle();
      }
      if(showOverlay){
        fill(255);
        textAlign(LEFT);
        text("slice: " + trans[currentSlice].sliceName, 10, 20);
        text("x: " + trans[currentSlice].xy.x, 10, 40);
        text("y: " + trans[currentSlice].xy.y, 10, 60);
        text("rotation: " + trans[currentSlice].rotation, 10, 80);
        text("mirrored: " + trans[currentSlice].mirrored, 10, 100);
        text("slices skipped from last: " + trans[currentSlice].slicesSkippedFromLast,
             10, 120);
        text("voxel subdivision modifier: " + subDiv, 10, 140);
        textAlign(RIGHT);
        text("Controls:", 980, 20);
        text("Move slice: DRAG LEFT MOUSE", 980, 40);
        text("Rotate slice: SHIFT + WHEEL", 980, 60);
        text("Flip slice: F", 980, 80);
        text("Change slice: WHEEL", 980, 100);
        text("Create region of interest: DRAG RIGHT MOUSE", 980, 120);
        text("Show region of interest (in 2D and 3D): R", 980, 140);
        text("Load previously saved transformations: L", 980, 160);
        text("Save current transformations: S", 980, 180);
        text("Create 3D voxel data\n(do this before swapping to 3D view): C", 980, 
             200);
        text("View swap to 3D: V", 980, 240);
        text("Change slices skipped from last: [ ]", 980, 260);
        text("Toggle Overlay on/off: O", 980, 280);
        text("SubDivide voxels: D", 980, 300);
        text("Toggle Brain Outline (in 3D): O", 980, 320);
        text("Align Outline (in 3D): RDFGZXCVBN[]", 980, 340);
        text("Save/Load Outline alignment (in 3D): S/L", 980, 360);
      }
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
        rotateX(brainTrans.xyzRot.x);
        rotateY(brainTrans.xyzRot.y);
        rotateZ(brainTrans.xyzRot.z);
        scale(brainTrans.scale * subDiv);
        
        shape(mouseBrain);
      popMatrix();
      filter(edges);   //everything drawn so far will be rendered with the filter
      if(keyPressed){
        moveBrain();
      }
      noLights();      //afterwards show voxels/point cloud with pure colors
    }
    try{
      for(PShape s : voxels){
        shape(s);
      }
    } catch(Exception e){
      println(e);
      exit();
    }
  }
}

void createVolume(){
  //println(umPerPixel);                        //11.816711
  //since our depth is 70um we would like a 70x70x70um voxel as default voxel.
  //=> we want 1 pixel to be 70um 
  //11.816711u/pix * scaling = 70u/pix => x = 70/11.816711 = 5.923814
  float targetScaling = 70 / umPerPixel;
  println("rescaling pixels into voxels by factor: " + targetScaling);    //5.923814
  //if the um/pix doubles, the image width halves. =>
  //divide the image width (=height=1000) through this same value
  int newImgWidth = int(round(1000 / targetScaling));
  //168.8101571 rounded to 169 => a 169x169 pix image
  //This rounding (from 168.8101571 to 169) creates a very small inaccuracy in the xy
  //extent of voxels that could be reduced with larger voxels in a future version
  println("volume width(=height) without subdivisions: " + newImgWidth + " voxels");
  if(subDiv != 1){
    println("subdivididing each voxel into: " + int(sq(subDiv)) + " voxels in x/y");
    newImgWidth *= subDiv;            //i.e. 2x the newImgwidth => 4x the voxels
    println("the maximum volume dimension is " + newImgWidth + " voxels long.");
    println("please note that a maxium dimension of over 1000 voxels is not " +
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
    if(!pointCloud){
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
      println("created slice " + i + " voxel data");
      points.endShape();
      voxels[i].addChild(points);
    }
  }
  voxCols = null;
  System.gc();
  println("Free memory: " + Runtime.getRuntime().freeMemory());
}

void keyPressed(){
  if(key == 'l'){
    println("Loading transformations");
    loadTransformations();
  }
  if(key == 's'){
    println("Saving transformations");
    saveTransformations();
  }
  if(show2D){
    if(key == 'f'){
      println("Flipping the image on the y axis");
      flipSlice(currentSlice);
      trans[currentSlice].mirrored = !trans[currentSlice].mirrored;
    }
    if(key == 'c'){
      println("Creating 3D shape from images and transformations");
      createVolume();
      println("Done creating 3D shape");
    }
    if(key == 'v'){
      println("View swap to 3D\nplease wait a couple of seconds");
      //a lot of scrolling may have happened in 2D view => reset the camera
      cam.reset();
      show2D = false;
    }
    if(key == 'r'){
      showRoi = !showRoi;
    }
    if(key == '['){
      trans[currentSlice].slicesSkippedFromLast--;
      trans[currentSlice].slicesSkippedFromLast = 
                          max(trans[currentSlice].slicesSkippedFromLast, 0);
    }
    if(key == ']'){
      trans[currentSlice].slicesSkippedFromLast++;
    }
    if(key == 'o'){
      showOverlay = !showOverlay;
    }
    if(key == 'd'){
      subDiv += 1;
      if(subDiv == 6){
        subDiv = 1;
      }
    }
  } else {
    if(key == 'o'){
      showOutline = !showOutline;
    }
   //if(key == 'v'){
   //   println("View swap to 2D");
   //   show2D = true;
   // }
  }
}

void mouseWheel(MouseEvent event){
  float e = event.getCount();              //up = -1, down = 1
  //println(keyCode);
  if(show2D){
    if(!(keyPressed && keyCode == 16)){    //SHIFT key not pressed
      if(e == -1){
        currentSlice++;
      } else if (e == 1){
        currentSlice--;
      }
      currentSlice = constrain(currentSlice, 0, trans.length-1);
      println("switched to current slice: ", currentSlice);
    } else {
      trans[currentSlice].rotation += e*rotIncrement;
    }
  }
}

void mouseDragged(){
  if(show2D){
    if(mouseButton == 37){
      trans[currentSlice].xy.x += mouseX - pmouseX;
      trans[currentSlice].xy.y += mouseY - pmouseY; 
    } else if (mouseButton == 39){
      for(Transformation t : trans){  //update what is currently being drawn
        t.roi[1].x = mouseX;
        t.roi[1].y = mouseY;
      }
    }
  }
}


void mousePressed(){
  if(show2D && mouseButton == 39){   //39 = right mouse button
    for(Transformation t : trans){
      t.roi[0].x = mouseX;
      t.roi[0].y = mouseY;
    }
  }
}

void mouseReleased(){
  if(show2D && mouseButton == 39){
    for(Transformation t : trans){
      t.roi[1].x = mouseX;
      t.roi[1].y = mouseY;
    }
  }
}

float findMaxImgDim(String path){
  //We want to resize the image down to 1000 width or height 
  //(whichever is larger) => need to find the maximum width or height of any image.
  int maxDim = 0;
  //loading 30 large images just for finding the largest image dimension would be 
  //taking uneccessary time => just read the bytes and take the width and height
  //from the .png header
  
  byte b[] = new byte[]{};
  for(int i=0; i<slices.length; i++){
    String fileName = path + "/slices/" + fileNames[i];
    b = loadBytes(fileName);
    byte[] w = subset(b, 16, 4);    //width are 4 bytes [16 to 19], i.e. 0 0 50 -46
    //printArray(b);                //8 bit bytes are values  between -128 and 127 
    //for(int j=0; j<4; j++){
    //  println(int(b[j]));
    //}
    int madeInt = 0;                //50, -46 will become the ints 50, 210
    madeInt += int(w[1]) * 256 * 256;   
    madeInt += int(w[2]) * 256;   
    madeInt += int(w[3]);           //(50x256)+210 = 13010
    maxDim = max(maxDim, madeInt);
    byte[] h = subset(b, 20, 4);   //height bytes are [20 to 23]
    madeInt = 0;
    madeInt += int(h[1]) * 256 * 256;   
    madeInt += int(h[2]) * 256;   
    madeInt += int(h[3]);      
    maxDim = max(maxDim, madeInt);  
    println("maximum image width or height by slice: " + i + ": " + maxDim);
  }
  return float(maxDim);
}

void flipSlice(int i){
  PGraphics temp = createGraphics(slices[i].width, slices[i].height);
  temp.beginDraw();
    temp.translate(temp.width/2, temp.height/2);
    temp.scale(-1.0, 1.0);
    temp.imageMode(CENTER);
    temp.image(slices[i], 0, 0);
    slices[i] = temp;
  temp.endDraw();
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

void loadTransformations(){
  Table table = loadTable("transformations.csv");
  //keep a reference to the old transformation array for if something was mirrored
  Transformation[] oldTrans = new Transformation[trans.length];
  arrayCopy(trans, oldTrans);
  trans = new Transformation[trans.length];
  for(int i=0; i<trans.length; i++){
    trans[i] = new Transformation();
  }
  for(int line=1; line<table.getRowCount(); line++){
    int i = line-1;
    try{
      trans[i].sliceName = table.getString(line, 0);
      trans[i].xy.x = table.getFloat(line, 1);
      trans[i].xy.y = table.getFloat(line, 2);
      trans[i].rotation = table.getFloat(line, 3);
      if(table.getInt(line, 4) == 1 && !oldTrans[i].mirrored){
        //this slice should be mirrored, but isn't yet
        flipSlice(i);
        trans[i].mirrored = true;
      } else if (table.getInt(line, 4) == 0 && oldTrans[i].mirrored){
        //this slice should not be mirrored, but is
        flipSlice(i);
        trans[i].mirrored = false;
      }
      trans[i].mirrored = table.getInt(line, 4) == 1;
      trans[i].roi[0].x = table.getInt(line, 5);
      trans[i].roi[0].y = table.getInt(line, 6);
      trans[i].roi[1].x = table.getInt(line, 7);
      trans[i].roi[1].y = table.getInt(line, 8);
      trans[i].slicesSkippedFromLast = table.getInt(line, 9);
      println("loaded slice " + i + " transformations"); 
    } catch(ArrayIndexOutOfBoundsException e){
      println("there are more slices in the .csv file than were loaded by the " +
      "program\nskipping transformations for slice " + i);
    }
  }
  brainTrans.xyz.x = table.getFloat(0, 0);
  brainTrans.xyz.y = table.getFloat(0, 1);
  brainTrans.xyz.z = table.getFloat(0, 2);
  brainTrans.xyzRot.x = table.getFloat(0, 3);
  brainTrans.xyzRot.y = table.getFloat(0, 4);
  brainTrans.xyzRot.z = table.getFloat(0, 5);
  brainTrans.scale = table.getFloat(0, 6);
}

void saveTransformations(){
  Table table = new Table();
  for(int i=0; i<10; i++){
    table.addColumn();
  }
  table.addRow();
  table.setFloat(0, 0, brainTrans.xyz.x);
  table.setFloat(0, 1, brainTrans.xyz.y);
  table.setFloat(0, 2, brainTrans.xyz.z);
  table.setFloat(0, 3, brainTrans.xyzRot.x);
  table.setFloat(0, 4, brainTrans.xyzRot.y);
  table.setFloat(0, 5, brainTrans.xyzRot.z);
  table.setFloat(0, 6, brainTrans.scale);
  for(int i=0; i<trans.length; i++){
    int line = i+1;
    table.addRow();
    table.setString(line, 0, trans[i].sliceName);
    table.setFloat(line, 1, trans[i].xy.x);
    table.setFloat(line, 2, trans[i].xy.y);
    table.setFloat(line, 3, trans[i].rotation);
    table.setInt(line, 4, trans[i].mirrored ? 1 : 0);
    table.setInt(line, 5, int(trans[i].roi[0].x));
    table.setInt(line, 6, int(trans[i].roi[0].y));
    table.setInt(line, 7, int(trans[i].roi[1].x));
    table.setInt(line, 8, int(trans[i].roi[1].y));
    table.setInt(line, 9, trans[i].slicesSkippedFromLast);
  }
  saveTable(table, "data/transformations.csv");
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

void moveBrain(){
  //may want to use booleans to allow multiple keys at the same time if necessary
  if(key == 'd'){brainTrans.xyz.x -= 0.5;}
  if(key == 'g'){brainTrans.xyz.x += 0.5;}
  if(key == 'e'){brainTrans.xyz.y -= 0.5;}
  if(key == 't'){brainTrans.xyz.y += 0.5;}
  if(key == 'r'){brainTrans.xyz.z += 0.5;}
  if(key == 'f'){brainTrans.xyz.z -= 0.5;}
  
  if(key == 'z'){brainTrans.xyzRot.x -= 0.002;}
  if(key == 'x'){brainTrans.xyzRot.x += 0.002;}
  if(key == 'c'){brainTrans.xyzRot.y -= 0.002;}
  if(key == 'v'){brainTrans.xyzRot.y += 0.002;}
  if(key == 'b'){brainTrans.xyzRot.z -= 0.002;}
  if(key == 'n'){brainTrans.xyzRot.z += 0.002;}
  
  if(key == ']'){brainTrans.scale *= 1.001;}
  if(key == '['){brainTrans.scale *= 0.999;}
}
