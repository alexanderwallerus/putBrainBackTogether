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
      println("Completed creating 3D shape");
      println("View swap to 3D\nplease wait a couple of seconds");
      //a lot of scrolling may have happened in 2D view => reset the camera
      cam.reset();
      show2D = false;
    }
    //separate volume creation and view swapping for debugging
    if(key == 'b'){  
      println("Creating 3D shape from images and transformations");
      createVolume();
      println("Completed creating 3D shape");
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
    if(key == 'a'){
      if(!alignOutline){
        alignOutline = true;
        cam.setActive(false);
      } else {
        alignOutline = false;
        cam.setActive(true);
      }
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
  } else {
    if (showOutline && alignOutline){
      if(e == -1){brainTrans.scale *= 1.001;}
      if(e ==  1){brainTrans.scale *= 0.999;}
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
  } else {
    if(showOutline && alignOutline){
      //May want to in the future also control the rotX (Roll) of the YZX euler
      //rotation with left mouseDragged, by gradually switching from 100% rotYZ to 
      //100% rotX the more the cursor is away from the screen center.
      //Maybe even use polar coordinate angle velocity to define the amount.
      if(mouseButton == 37){
        //rotate the outline to any spherical angle around Y and Z
        brainTrans.xyzRot.y -= (mouseX - pmouseX) * 0.002;
        brainTrans.xyzRot.z -= (mouseY - pmouseY) * 0.002;
      } else if(mouseButton == 39){
        //roll the outline around its relative x axis
        float rightDrag = ((mouseX - pmouseX) + (mouseY - pmouseY))/2;
        brainTrans.xyzRot.x += rightDrag * 0.002;
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

void moveBrainOutline(){
  //may want to use booleans to allow multiple keys at the same time if necessary
  if(key == 'd'){brainTrans.xyz.x -= 0.5;}
  if(key == 'g'){brainTrans.xyz.x += 0.5;}
  if(key == 'e'){brainTrans.xyz.y -= 0.5;}
  if(key == 't'){brainTrans.xyz.y += 0.5;}
  if(key == 'r'){brainTrans.xyz.z += 0.5;}
  if(key == 'f'){brainTrans.xyz.z -= 0.5;}
}
