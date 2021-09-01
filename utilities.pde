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

void loadTransformations(){
  Table table = loadTable("transformations/transformations.csv");
  if(table == null){
    println("No transformations.csv found. Please either add your existing" +
            "transformations.csv file to the transformations folder, or save your" +
            "current transformations by pressing \"S\" to create one.");
    return;
  }
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
  saveTable(table, "transformations/transformations.csv");
}


//Functions for parsing folders:
String[] listFileNames(String dir){  //return all files in a directory as Str Array
  File file = new File(dir);
  if (file.isDirectory()) {
    String names[] = file.list();
    return names;
  } else {
    return null;  //If it's not a directory
  }
}

File[] listFiles(String dir){  //return all files in a directory as File object Array
  File file = new File(dir);   //=> useful for showing more info about the files
  if (file.isDirectory()) {
    File[] files = file.listFiles();
    return files;
  } else {
    return null;   //If it's not a directory
  }
}

ArrayList<File> listFilesRecursive(String dir){ //=> list of all files in a directory
  ArrayList<File> fileList = new ArrayList<File>();  //and all subdirecties
  recurseDir(fileList, dir);
  return fileList;
}

void recurseDir(ArrayList<File> a, String dir){  //Recursive function to traverse 
  File file = new File(dir);                     //subdirectories
  if (file.isDirectory()) {
    //If you want to include directories in the list
    a.add(file);  
    File[] subfiles = file.listFiles();
    for (int i = 0; i < subfiles.length; i++) {
      //Call this function on all files in this directory
      recurseDir(a, subfiles[i].getAbsolutePath());
    }
  } else {
    a.add(file);
  }
}
