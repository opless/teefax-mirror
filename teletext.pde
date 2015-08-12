/* @pjs font="teletext2.ttf"; */
/* @pyjamas font="MODES___.TTF"; */

/** ***************************************************************************
 * Title      : teletext.pde
 * Description       : In-browser Teletext viewer 
 * 
 * This code goes into an HTML5 canvas to display a teletext service.
 * A teletext sevice consists of a number of teletext pages.
 * To create a teletext service place these files in web server
 *
 * 1) processing.min.js library. This is the Processing2 Javascript system.
 * 2) This source code teletext.pde
 * 3) An HTML file that includes these two lines
 *     <script src="processing.min.js"></script>
 *     <canvas data-processing-sources="teletext.pde"></canvas>
 * 4) The teletext pages in MRG Systems .tti format (7 bit escaped version)
 * 
 * Platform          : Processing2 Javascript
 *
 * Copyright (C) 2014, Peter Kwan
 *
 * Permission to use, copy, modify, and distribute this software
 * and its documentation for any purpose and without fee is hereby
 * granted, provided that the above copyright notice appear in all
 * copies and that both that the copyright notice and this
 * permission notice and warranty disclaimer appear in supporting
 * documentation, and that the name of the author not be used in
 * advertising or publicity pertaining to distribution of the
 * software without specific, written prior permission.
 *
 * The author disclaims all warranties with regard to this
 * software, including all implied warranties of merchantability
 * and fitness.  In no event shall the author be liable for any
 * special, indirect or consequential damages or any damages
 * whatsoever resulting from loss of use, data or profits, whether
 * in an action of contract, negligence or other tortious action,
 * arising out of or in connection with the use or performance of
 * this software.
 ****************************************************************************/

/* To keep compatibility with processing.js,
 All StringBuffer and char have been banished */
 
// Layout
float ttxHeight, ttxWidth, keypadHeight;
PFont ttxFont;
float cellWidth;
float cellHeight;
int ttxFontSize;
int j=0;

// Compatibility
Boolean droidMode;
Boolean javascriptMode=false;

// Page
int g_currentPage; // The page mpp (without subpage)
String g_prefix="P";
String g_postfix=".ttix"; // -N.TTI
int g_homepage=0x100;
Boolean gFlash; // 3Hz  
String channelID="    FRINGEFAX     "; // How many characters exactly? 18 at the moment
TTX ttx;

// User controls
Boolean[] g_pressed;  // Fastext 
Boolean g_Hold;
Boolean g_Reveal;

// Keypad
Boolean g_numericKeys; // Set when the numeric keypad is active
int g_numZoom;
int [] g_digits;

// Javascript
// Doesn't work :-(
interface Javascript {}
Javascript javascript=null;
void bindJavascript(Javascript js) { javascript=js; }

void setup()
{ 
  /* */
  g_numericKeys=false;
  g_numZoom=0;
  g_pressed=new Boolean[17]; // 10 digits, 4 links, Index, Hold, Reveal
  g_digits=new int[3];  // keypad digits
  for (int i=0;i<3;i++) g_digits[i]=0;
  for (int i=0;i<17;i++)
    g_pressed[i]=false;  
  // 0=Java, 1=Android, 2=js
  switch (2)
  {
	case 0:
		size(400,600); // Comment out this line for Android
		droidMode=false;
		break;
	case 1:
		droidMode=true;
		break;
	case 2:
		size(480,640); // Comment out this line for Android
		droidMode=false;
                javascriptMode=true;
		break;
  }
  cellWidth=int(width/40); // Need explicit int for JavaScript
  setupFont();
  frameRate(5);
  g_homepage=0x100;
  g_currentPage=0x100;
  ttx=new TTX(g_prefix+hex(g_currentPage,3)+g_postfix);
}

/************** FONT *****/

void setupFont()
{
  // All metrics are based on the width
  ttxWidth=width;
  // Load the Mode Seven font
  //ttxFont=loadXFont("ModeSeven-48.vlw");
  ttxFont=createFont("teletext2.ttf",48);  
//  ttxFont=createFont("MODES___.TTF",48);  tt
  textFont(ttxFont);
  // Scale the font to fit (based on 40 characters at size 48)
  textSize(48.0);
  float m_Width=textWidth("1111111111222222222233333333334444444444");
  ttxFontSize=int(48*ttxWidth/m_Width);
  // Set the actual font size
  // println("Font size for this display="+ttxFontSize);
  textSize(ttxFontSize);
  // Set the global ttx panel height
  ttxHeight=ttxFontSize*25+4;  // Based on 25 lines of text (plus fudge factor)
  keypadHeight=height-ttxHeight;
  // finally set up the character cell sizes
  ttxWidth=textWidth("1111111111222222222233333333334444444444");  
  cellWidth=int(ttxWidth/40); // int for Javascript
  cellHeight=ttxFontSize;  
}

/* This is the main draw() */
void draw()
{
  gFlash=(millis()%600)>300;
  background(100);
  // drawPage();
  /* Load the homepage if there is a bad link */
  if (!drawPage())
  {
    // println("draw is reverting to homepage");
    ttx.loadPage(g_prefix+hex(g_homepage,3)+g_postfix);
    g_currentPage=g_homepage;
  }
  drawKeypad();
  drawNumericKeys();
}

/** Keyboard handler
 * On key typed, this is called.
 * If it is a number we treat it like the key pad
 */
void keyTyped()
{
  acceptKeypadDigit(key-'0');  
}

/** Accept the next Character
 * \param digit : Get the next digit 0..9 from keypad or mousepad
 * Accepts the digit and shift it.
 * If it is a valid page then go to the page
 */
void acceptKeypadDigit(int digit)
{
  int pageNumber;
  if (digit<0 || digit>9) return; // NaN
  // If it is a new number, clear the number
  if (!g_numericKeys) 
  {
    g_numericKeys=true; // Make keypad active if not already
    g_digits[2]=0;
    g_digits[1]=0;
    g_digits[0]=0;
  } 
  // shift and replace the first digit
  g_digits[2]=g_digits[1];
  g_digits[1]=g_digits[0];
  g_digits[0]=digit;
  // Find the page number as an integer
  pageNumber=g_digits[2]*0x100+g_digits[1]*0x10+g_digits[0];
  // Try to load the page
  if (pageNumber>=0x100 && pageNumber<=0x8FF)
  {
    // println("imma load the page"+g_prefix+hex(pageNumber,3)+g_postfix);
    if (ttx.loadPage(g_prefix+hex(pageNumber,3)+g_postfix ))
    { // failed
      // println("fail");
    }
    else
    {  // worked
      g_currentPage=pageNumber;
      g_numericKeys=false;
      for (int i=0;i<3;i++) g_digits[i]=0;
      // println("pass");
    }
  }
}

void drawNumericKeys()
{
  int step=50; // set the speed here. Native app =18, Javascript needs to be faster
  if (g_numZoom>0 && g_numZoom<255)
      frameRate(50);
  if (g_numericKeys)
  {
    if (g_numZoom<255  && false) // Don't animate in. Too slow!
      g_numZoom+=step;
    else
      g_numZoom=255;    
    
  }
  else
  {
    if (g_numZoom>0)
      g_numZoom-=step;
    else
    {
      g_numZoom=0;
      frameRate(5);  // save CPU!
    }
  }
  if (g_numZoom<=0) return; // Don't show
  stroke(255,255,255,180);
  fill(0,0,0,0);
  rect(10,10,lerp(10,width-20,g_numZoom/255.0),lerp(10,ttxHeight-20,g_numZoom/255.0));
  float f=g_numZoom/255.0;
  int r=10; // button radius
  int gap=10;
  int kpw=int(lerp(gap,width-2*gap,f)); // keypad width
  int kph=int(lerp(gap,ttxHeight-2*gap,f)); // keypag height
  int third=int(kpw/3.0); // might want borders TBA
  int qtr=int(kph/4.0);
  color c=color(255,255,255,lerp(50,100,f));
  textSize(lerp(ttxFontSize,ttxFontSize*4,f));
  for (int col=0;col<3;col++)
  {
    for (int row=0;row<3;row++)
    {
      fill(c);
      rect(gap+col*third,gap+row*qtr,third-gap*2,qtr-2*gap,r,r,r,r);
      fill(255,255,255,150);
      text(col+1+row*3,gap*2+col*third,(row+1)*qtr-gap*2);
    }
  }
  fill(c);
  rect(gap+third,gap+3*qtr,third-gap*2,qtr-2*gap,r,r,r,r); // The lonely 0
  text("0",gap*2+third,4*qtr-gap*2);
  textSize(ttxFontSize);
}

/*** Handle all mouse presses.
 * 1) Keypad buttons
 * 2) Numeric keypadHeight
 * 3) Links in pages. 
 */
void mousePressed()
{
  int page;
  if (g_numericKeys)  // Numeric keypad....
  {
    mouseNumeric(mouseX, mouseY);
  }
  else // Or look for links in the current page
  {
    page=ttx.mousePressed(mouseX, mouseY);
    if (page!=0)
    {
      g_currentPage=page;
      ttx.loadPage(g_prefix+hex(g_currentPage,3)+g_postfix);
    }
  }
  // Buttons at the bottom are always active
  mouseKeypad(mouseX, mouseY);
}  
  
Boolean drawPage()
{
  fill(0);
  rect(0,0,width,ttxHeight);
  return ttx.draw();
}

void button(float x, float y, color c, Boolean down)
{
  fill(c);
  if (down)
    stroke(0);
  else
    stroke(255);
  strokeWeight(4);
  rect(x,y,width/4,keypadHeight*0.5);
}

void drawKeypad()
{
  fill(50,0,0);
  rect(0,ttxHeight,width,keypadHeight);
  int i=0;
  button(i++*width/4,ttxHeight,color(255,0,0),g_pressed[0]);  
  button(i++*width/4,ttxHeight,color(0,255,0),g_pressed[1]);  
  button(i++*width/4,ttxHeight,color(255,255,0),g_pressed[2]);  
  button(i++*width/4,ttxHeight,color(0,255,255),g_pressed[3]);
  // Droidfax page  
  button(0*width/4  ,ttxHeight+keypadHeight/2,color(0,0,255),g_pressed[5]);
  button(1*width/4  ,ttxHeight+keypadHeight/2,color(0,0,255),g_pressed[6]);
  //button(2*width/4  ,ttxHeight+keypadHeight/2,color(0,0,255),g_pressed[4]);
  button(3*width/4  ,ttxHeight+keypadHeight/2,color(0,0,255),g_pressed[4]);
  fill(255,255,0);
  text("HOLD ",0.1*width/4,ttxHeight+keypadHeight*1.5/2);
  text("REVEAL",1.1*width/4,ttxHeight+keypadHeight*1.5/2);
  //text("INDEX",2.1*width/4,ttxHeight+keypadHeight*1.5/2);
  text("INDEX",3.1*width/4,ttxHeight+keypadHeight*1.5/2);
  // rect(3.1*width/4,ttxHeight+keypadHeight*1.5/2,20,20);
  
  // Numeric keypad symbol
  float qtr=ttxWidth/4.0;
  float x0=2.1*qtr;
  float y0=ttxHeight+keypadHeight/2;
  float dx=qtr/5;
  float dy=keypadHeight/9;
  fill(0);
  stroke(255);
  strokeWeight(1);
  for (int col=0;col<3;col++)
    for (int row=0;row<4;row++)
    {
      if (row<3 || col==1)
        rect(x0+dx*col,y0+dy*row,qtr/6,keypadHeight/10,3,3,3,3);
    }
}

// A service is a set of files named
// <fileprefix><filehomepage><filepostix>
// such as BBC100.ttix
void SetChannel(String fileprefix, int filehomepage, String filepostfix, String channel)
{
  g_prefix=fileprefix;
  g_postfix=filepostfix;
  g_homepage=filehomepage;
  g_currentPage=g_homepage;
  channelID=channel;
  ttx.loadPage(g_prefix+hex(g_currentPage,3)+g_postfix );
}

// The mouse handler for the numeric keypad
void mouseNumeric(int x, int y)
{
  int bx; // button x
  int by;
  int keyNumber;
  if (!g_numericKeys) return; // Is keypad active?
  if (y>ttxHeight) return; // Not on the keypad?
  bx=int(x*3.0/ttxWidth); // button column
  by=int(y*4.0/ttxHeight); // button row
  // println("Button ("+bx+","+by+")");
  keyNumber=bx+1+by*3; // most keys can be calculated
  switch (keyNumber) // with these exceptions
  {
    case 10: return;  // invalid (possible extra keys?)
    case 12: return;
    case 11: keyNumber=0; break;
  }
  acceptKeypadDigit(keyNumber);  
  // println("Key="+g_digits[2]+g_digits[1]+g_digits[0]);
}

void mouseKeypad(int x, int y)
{
  if (y<ttxHeight) return;
  int button=int(x*4/width);
  int link=ttx.GetFastextLink(button);
  // Is it the INDEX button?
  if (y<(ttxHeight+keypadHeight/2)) // Fastext
  {
    g_pressed[button]=true; // This sets it. Released after page is loaded.
  }
  else
  switch (button)
  {
    case 0:  // Hold
      g_pressed[5]=true;
      g_Hold=!g_Hold;
      link=99;  // This isn't a real link
      break;     
    case 1:  // Reveal
      g_pressed[6]=true;
      link=99; // This isn't a reallink either
      g_Reveal=!g_Reveal;
      break;  
    case 2: // Numeric keypad
      // Select numeric keypad mode and leave it for draw() to do
      g_numericKeys=!g_numericKeys;
      for (int i=0;i<3;i++) g_digits[i]=0;  // When you press the button clear the digits 
      link=99;
      break;   
    case 3:  // Index (MENU100.ttix)
      // if not in droidfax mode and not on the default page
      // println("BLAH="+g_prefix+", "+g_currentPage+"!="+g_homepage);
      if (!g_prefix.equals("MENU") && g_currentPage!=g_homepage)
      { // Go to the default page for this channel
        link=g_homepage;
        // println("setting homepage");
      }
      else
      { // Go to the Droidfax root page
        link=1;
      }
      g_pressed[4]=true;
      break;     
  }
  // println("[mouseKeypad]Pressed button "+button+" link="+link);
  // Set the various services from here (Invalid links less than 0x100) (Link=A..D etc)
  switch (link)
  {
    case 0x01:  // Main Droidfax menu
      SetChannel("MENU",0x100,".ttix","    DR01DFAX      ");
      break;
    case 0x0a: // BBC
      SetChannel("BBC",0x100,".ttix","  CEEFAX 1        ");
      break;
    case 0x0b: // LAY
      SetChannel("LAY",0x102,"-N.TTIx","  CEEFAX 1       ");
      break;
    case 0x0c: // Do you go where I go?
      SetChannel("P",0x401,".ttix"  ,"  DO YOU GO?      ");
      break;
    case 0x0e: // Art gallery
      SetChannel("Gallery/GAL",0x100,".ttix"," Art Gallery      ");
      break;
    case 0x0f: // HTV West
      SetChannel("readback/R",0x100,"00.TTIx"," HTV West         ");
      break;
    case 0x10: // Bamboozle
      // SetChannel("BB",0x152,".TTIx","BNYTeletext  BW   ");
      SetChannel("BB",0x152,".TTIx",fromCharCode(TTX.ttxCodeAlphaBlue)+
        fromCharCode(TTX.ttxCodeNewBackground)+
        fromCharCode(TTX.ttxCodeAlphaYellow)+
        "Teletext  "+
        fromCharCode(TTX.ttxCodeBlackBackground)+
        fromCharCode(TTX.ttxCodeAlphaWhite)+
        "   ");
      break;      
    case 0x11: // Teletext40
      SetChannel("teletext40/TFORTY",0x100,".ttix"," teletext40.com   ");
      break;
    case 0x12: // MRG Test
      SetChannel("test/",0x200,".TTIx"," MRGFAX           ");
      break;
    case 0x13: // Not yet in use
      SetChannel("path",0x100,".ttix"," header goes here ");
      break;
  }  
  if (link>0xff)
  {
    // println("gunna load "+hex(link));
    ttx.loadPage(g_prefix+hex(link,3)+g_postfix );
    g_currentPage=link;
  }

}

/****** TTX Class *****/
class TTX
{
  // Constants
  private static final int ttxCodeAlphaBlack = 0;  // Not level 1 teletext
  private static final int ttxCodeAlphaRed = 1;
  private static final int ttxCodeAlphaGreen = 2;
  private static final int ttxCodeAlphaYellow = 3;
  private static final int ttxCodeAlphaBlue = 4;
  private static final int ttxCodeAlphaMagenta = 5;
  private static final int ttxCodeAlphaCyan = 6;
  private static final int ttxCodeAlphaWhite = 7;
  private static final int ttxCodeFlash = 8;
  private static final int ttxCodeSteady = 9;
  private static final int ttxCodeEndBox = 10;
  private static final int ttxCodeStartBox = 11;
  private static final int ttxCodeNormalHeight = 12;
  private static final int ttxCodeDoubleHeight = 13;
  private static final int ttxCodeGraphicsBlack = 16; // non standard!!! Dan Farrimond mode
  private static final int ttxCodeGraphicsRed = 17;
  private static final int ttxCodeGraphicsGreen = 18;
  private static final int ttxCodeGraphicsYellow = 19;
  private static final int ttxCodeGraphicsBlue = 20;
  private static final int ttxCodeGraphicsMagenta = 21;
  private static final int ttxCodeGraphicsCyan = 22;
  private static final int ttxCodeGraphicsWhite = 23;
  private static final int ttxCodeConcealDisplay = 24;
  private static final int ttxCodeContiguousGraphics = 25;
  private static final int ttxCodeSeparatedGraphics = 26;
  private static final int ttxCodeEscape = 27;
  private static final int ttxCodeBlackBackground = 28;
  private static final int ttxCodeNewBackground = 29;
  private static final int ttxCodeHoldGraphics = 30;
  private static final int ttxCodeReleaseGraphics = 31;
  
  private static final int SBMAX = 60; // 40 chars plus a few for escapes
  // Member vars 
  private int m_PageNumber; // PN (Note! This is hex)
  private int m_CycleSecs; // CT - Default 15
  private String m_CycleType;  // CT - T(imed) or C(ycled)
  private int m_SequenceCode;  // Only used for carousels
  private int m_PageStatus;  // Transmission flags
  private byte[] mPage;  // The page but binary (sigh) Why did I do this?? (Doesn't work on Javascript)
  private ArrayList<TTXLink> m_links;
  private int[] fastextLinks = new int[6];
  
  private int[] m_subpageList; // For carousels
  private int m_subpageCount; 
  
  private int m_CarouselIndex;
  private int m_CarouselExpires;
  
  void inits()
  {
    // initialisations
    m_links.clear();
    m_subpageList=new int[50];    
    m_subpageCount=0;
    m_CarouselIndex=1;
    m_CarouselExpires=millis(); /* +8*1000; */
    for (int i=0;i<6;i++) fastextLinks[i]=0;
    m_CycleSecs=8;
    m_CycleType="T";
    m_SequenceCode=0;
    
    // Globals
    g_Hold=false;
    g_Reveal=false;
  }
  
  // Constructor(s)
  TTX (String filename)
  {
    // println("Created TTX object");
    m_links=new ArrayList<TTXLink>();
    loadPage(filename);
  }
  
  // Member methods
  Boolean loadPage(String ttxFile)
  {
    inits();
    // println("loading..."+ttxFile);
    // Invalidate the old page
    if (m_PageNumber>0x100) m_PageNumber=-m_PageNumber;
    mPage=loadBytes(ttxFile);
    if (mPage==null) // This doesn't work
    {
      // println("Failed to load..."+ttxFile+", tell Peter!");
      return false;
    }
    /* Dump the page to console
    for (int i=0;i<mPage.length();i++)
    {
      mPage[i]=mPage[i] & 0xff;
      print(hex(mPage[i],2)+" ");
      if (i%40==0) println("");
    }
    return;
    */
    for (int i=0;i<17;i++) g_pressed[i]=false;
    return this.parseMeta(ttxFile);
  }
  
  // Returns true if the page number is invalid
  Boolean parseMeta(String filename)
  {
    Boolean debugmeta=true;
    String[] pg=loadStrings(filename);
    m_PageNumber=-1;
    for (int i=0;i<pg.length;i++)
      if (pg[i]!=null)
      {
        String[] s=split(pg[i],',');
        if (s[0].equals("DE"))  // Description
        {
          // What to do with this?
          if (debugmeta) println("Description: "+pg[i].substring(3));
        }
        if (s[0].equals("PN"))  // Page number
        {
          m_PageNumber=unhex(s[1].toUpperCase());
          if (debugmeta)  println("Parsing page (hex): "+hex(m_PageNumber));
          m_subpageList[m_subpageCount++]=m_PageNumber; // Stack up the subpages  
        }
        if (s[0].equals("CT"))  // Cycle time
        {
          m_CycleSecs=int(s[1]);
          if (m_CycleType.length()>1)
            m_CycleType=s[2]; // Some old pages don't have the cycle type.
          else
            m_CycleType="T"; // Default to timed
          if (debugmeta)  println("CT decodes to "+m_CycleSecs+", "+m_CycleType);
        }
        if (s[0].equals("SC"))  // Sequence code?
        {
          m_SequenceCode=int(s[1]);
          if (debugmeta)  println("Sequence code is "+m_SequenceCode);
        }
        if (s[0].equals("PS"))  // Page Status
        {
          m_PageStatus=unhex(s[1].toUpperCase());
          if (debugmeta)  println("Page Status is "+hex(m_PageStatus));
        } 
        // OL has meta data, match possible page numbers. 
        if (s[0].equals("OL"))  // Output line
        {
          findLinks(pg[i],m_PageNumber);
        } 
        // MS is mask. Don't need it. See Farnborough for details.
        // FL is fastext link. Don't need it just atm. 
        if (s[0].equals("FL"))  // Output line
        {
          for (int k=0;k<6;k++)
          {
            // println("Fastext link="+s[k+1]teletext);
            if (s[k+1].length()>3)
              s[k+1]=s[k+1].substring(0,2); 
            
            fastextLinks[k]=unhex(s[k+1].toUpperCase());
            if (debugmeta)  println("Fastext links:"+hex(fastextLinks[k]));
          }
        }         
      }
      return (m_PageNumber<0);
  }
  
  // Finds the links on this line
  void findLinks(String str, int pageNum)
  {
    int state=0;
    int commaCount=0;
    int row=0;
    int col=0;
    int link=0;
    int colStart=0;
    // state=0 Scanning commas
    // state=1 Scanning the text
    // println("Looking for links in "+str);
    for (int i=0;i<str.length();i++)
    {
      String ch=str.substring(i,i+1); // Use Strings, because Javascript doesn't have char type
      int ich=charCodeAt(ch,0);
      switch (state)
      {
        case 0: // scanning commas
          if (commaCount==0) {row=0;link=0;}
          if (ch.contains(",")) commaCount++;
          if (commaCount==2)  // Found the comma. Now parse text
          {
            col=0;    // The actual text starts now
            state=1;
          }
          if (ich>=0x30 && ich<=0x39) // Get the row number 
            row=row*10+(ich-0x30);
          break;
        case 1: // scanning text
          // if (row>0) println("Found row="+row);
          if (ich>=0x30 && ich<=0x39) // Could extend to hex 
          {
            if (link==0)
            {
              colStart=col; // first digit?
              // println("Found colStart="+colStart);
            }
            link=link*0x10+(ich-0x30);
            if ((i+1)==str.length())
              if (colStart>0 && link>=0x100 && link<=0x8FF && row>0 && row<25)
              {
                // println("LinkA found "+hex(link,3)+" at "+colStart+","+row);
                m_links.add(new TTXLink(colStart,row,link,pageNum));
                colStart=0;link=0;
              }
          }
          else // not a digit
          {
            if (colStart>0 && link>=0x100 && link<=0x8ff && row>0 && row<25)
            {
              // println("LinkB found "+hex(link,3)+" at "+colStart+","+row);
              m_links.add(new TTXLink(colStart,row,link,pageNum));
            }
            colStart=0;link=0;
          }
          if (charCodeAt(ch,0)!=0x1b) col++; // de-escape
          break;
      } // switch
      
    }
  }
  
/* draw parses the page for OL output lines and draws them*/
  Boolean draw() // ttx::draw
  {
    int row=0, col=0;
    int state=6;
    byte ch;
    int match=0;
    byte[] sb=new byte[SBMAX];
    for (int i=0;i<SBMAX;i++)
      sb[i]=' ';
    if (mPage==null) return false;
    

    // Draw the header. Where should this come from?
    String now=nf(hour(),2)+":"+nf(minute(),2)+"/"+nf(second(),2);
	//println("now="+now);
    
    String months="JANFEBMARAPRMAYJUNJULAUGSEPOCTNOVDEC";
    // String days="MONTUEWEDTHUFRISATSUN"; // Can't do day of week yet
    int m=(month()-1)*3;
    
    int p=m_PageNumber;
    if (p<0) p=-p; // Not found nonsense

    String numColour=" P";  // Normal start, a plain white P
    if (m_PageNumber<=0 || g_numericKeys)  // Unless the page is invalid then it is green
      numColour=fromCharCode(ttxCodeAlphaGreen)+"P";
   

    String pageNum=hex(int(p/0x100),3); // The display page number
    
    // Echo the numeric keypad
    int pn=g_digits[2]*0x100+g_digits[1]*0x10+g_digits[0];
    if (g_numericKeys)
    {
      pageNum=hex(pn,3);
    }
      
    
    if (g_Hold) pageNum="HOLD";

    String strPageHeader=numColour+pageNum+
      channelID+
      nf(day(),2)+" "+months.substring(m,m+3)+"  "+
      fromCharCode(ttxCodeAlphaYellow)+now+"abcdefghijklmnop";
    // println("strPageHeader="+strPageHeader);
    //fill(255);
    //text(strPage,0,cellHeight);
    
     drawRow(0,strPageHeader); 
    // 0 = start of line
    // 1 = skip and ignore until LF
    // 2 = expect L
    // 3 = expect comma
    // 4 = Copy the row number (expect comma)
    // 5 = copy the string until CR or LF
    // 6 = Expect P
    // 7 = Expect N
    // 8 = Expect ,
    // 9 - Get page number and and go to state 1
    
    // What page of the carousel are we on?
    if (millis()>m_CarouselExpires && !g_Hold)
    {
      m_CarouselIndex++;
      if (m_CarouselIndex>=m_subpageCount)
        m_CarouselIndex=0;
      m_CarouselExpires=millis()+8*1000; // Each subpage is 8 seconds
      //println("index="+m_CarouselIndex+", "+hex(m_subpageList[m_CarouselIndex],5));
    }
    String strPage=hex(m_subpageList[m_CarouselIndex],5);
    
    noStroke();
    for (int i=0;i<mPage.length;i++)
    {
      // ch=char(mPage[i]);
      ch=mPage[i];
      if (ch==0x10) ch=0x0d;  // CR mapping
      ch&=0x7f;
      // print(" ch="+hex(ch,2));
      // if (i%10==0) println("");
      switch (state)
      {
        case 0: if (ch==0x4F) // 'O'
                {
                  state=2;  // Expect L
                  // println("Found O");
                }
                else
                  state=1; // Skip to end
                if (ch==0x50 && mPage[i+1]==0x4E)  // Or end of page? 'P'50 'N'4E  
                  state=99;  
          col=0;
          row=0;
          // println("state="+state+" ch="+ch);
          break;
        case 1: if (ch==0x0a) state=0;break; // \n10
        case 2: if (ch==0x4C) state=3; else state=1; break; // 'L'
        case 3: if (ch==0x2c) state=4; else state=1; break; // ','
        case 4: if ((ch>=0x30) && (ch<=0x39)) // '0'30  '9'39
                {      
                  row=row*10+ch-0x30; // '0'
                  break;
                }
                if (ch==0x2c) // ','
                {
                  state=5;
                  // sb.setLength(SBMAX);
                  col=0;
                  for (int j=0;j<SBMAX;j++) sb[j]=' ';
                }
                else state=1; break;
        case 5: 
          if (ch==0x0a || (ch==0x0d && mPage[i+1]==0x0a) ) // \n10, \r13
          {
            // println("Found a row to print. r="+row+" First char="+sb[0]);
            // but don't draw row 0, the header
            if (row>0) drawRowChar(row,sb);
            if (ch==0x0a)
              state=0;  // LF terminated only
            else
              state=1; // CR/LF
          }
          else
          {
            if (col<SBMAX)
              sb[col++]=ch; // Javascript specific
              // print("ch="+ch);
          }
          break; 
        case 6:  //PN,xxxxx
          if (ch==0x50) state=7; else state=10; // 'P'50
          // println("Found P");
          break;
        case 7: // N
          if (ch==0x4e) state=8; else state=10; // 'N'4E
          // println("Found N");
          // pagenum=0;
          break;
        case 8: // comma
          if (ch==0x2c) state=9; else state=10; // ','2c
                    // println("Found comma");

          match=0;
          break;
        case 9: // Get number (could be hex!)
          if (match>=5) // Found the matching page
          {
            state=1;
            break;
          }
          if ((ch>=0x61) && (ch<=0x66)) // Convert lower case hex to upper case
            ch-=0x20;
          if (
            ( ((ch>=0x30) && (ch<=0x39)) || ((ch>=0x41) && (ch<=0x46)) ) 
            &&  ch==charCodeAt(strPage,match++)) break; // '0'30 '9'39
          state=10;
          break; 
        case 10: if (ch==0x0a) state=6;break;  // \n10        
      } // state machine
    } // for each byte
    // Tidy up the right hand side of the image by splatting a black rectangle over it.
    fill(0);
    rect(40*cellWidth,0,40,ttxHeight);
    smooth();
    return true;
  }
  
  /* Char array version. Needs to be Processing.js compatible */ 
  void drawRow(int r, String str)
  {
    byte[] b;
    b=new byte[SBMAX];
    for (int i=0;i<SBMAX;i++)
      b[i]=(byte)charCodeAt(str,i);
    // println("[drawRow] row="+r);
    this.drawRowChar(r,b);
  }
  
  void drawRowChar(int r, byte[] str)
  { 
    float rowAddress=r*cellHeight;
    float textRow=cellHeight*(r+1)-textDescent();
    color c=color(255,255,255);
    Boolean graphics=false;
    Boolean doubleHeight=false;
    Boolean contiguousGraphics=true;
    Boolean flashing=false;
    Boolean conceal=false;

    fill(255);
    // println("row "+r+", string "+str);
    //return; // Debug desperation
    // For each character, check if it is a special character
    // If not it defaults to a printable character

    int ix=0;
    // Scan the chars in the line, terminate when we have enough columns
    // OR if we hit an early CR/LF OR if we run out of buffer 
    // Actually, CR/LF will never get here so it is a useless test.
    for (int icol=0;icol<SBMAX && !(str[ix]==0x0d && (str[ix+1]==0x0a)) && icol<40;icol++,ix++)
    {
      float colAddress=float(icol)*cellWidth;
      byte j;
      
      j=str[ix];  // Java

      // De-escape
      if (str[ix]==0x1b)
      {
        ix++;
        j=byte(str[ix] & 0x3f);
      }

      switch (j)
      {
        // Modifiers
        case ttxCodeConcealDisplay: conceal=true;break;
        case ttxCodeDoubleHeight:
          if (icol<5)
          {
            doubleHeight=true;
            // println("Double height detected in column "+icol);
          }
          break; // Hack to avoid double height appearing by mistake due to formatting
        case ttxCodeContiguousGraphics: contiguousGraphics=true;break;
        case ttxCodeSeparatedGraphics: contiguousGraphics=false;break;
        // Alpha colours
        case ttxCodeAlphaBlack: graphics=false;c=color(0,0,0);break; // Not level 1! 
        case ttxCodeAlphaRed: graphics=false;c=color(255,0,0);break; 
        case ttxCodeAlphaGreen: graphics=false;c=color(0,255,0);break; 
        case ttxCodeAlphaYellow: graphics=false;c=color(255,255,0);break; 
        case ttxCodeAlphaBlue: graphics=false;c=color(0,0,255);break; 
        case ttxCodeAlphaMagenta: graphics=false;c=color(255,0,255);break; 
        case ttxCodeAlphaCyan: graphics=false;c=color(0,255,255);break; 
        case ttxCodeAlphaWhite: graphics=false;c=color(255,255,255);break;
        // Graphic colours
        case ttxCodeGraphicsBlack: graphics=true;c=color(0,0,0);break; // Farrimond mode
        case ttxCodeGraphicsRed: graphics=true;c=color(255,0,0);break;
        case ttxCodeGraphicsGreen: graphics=true;c=color(0,255,0);break; 
        case ttxCodeGraphicsYellow: graphics=true;c=color(255,255,0);break; 
        case ttxCodeGraphicsBlue: graphics=true;c=color(0,0,255);break; 
        case ttxCodeGraphicsMagenta: graphics=true;c=color(255,0,255);break; 
        case ttxCodeGraphicsCyan: graphics=true;c=color(0,255,255);break; 
        case ttxCodeGraphicsWhite: graphics=true;c=color(255,255,255);break;
        // Flashing
        case ttxCodeFlash:flashing=true;
          break;
        case ttxCodeSteady:flashing=false;
          break;
        // Background colour
        case ttxCodeBlackBackground: c=color(0,0,0); // fall through    
        case ttxCodeNewBackground:  // Paint the background now
          fill(c);
          rect(colAddress,rowAddress,width,cellHeight);
          break; 
        // Printable
        default:
          if (j<0x20 || j>0x80) break;
          noStroke();
          // noSmooth();  // damn you HTML5
          fill(c);
          if ((!flashing || gFlash) && (!conceal || g_Reveal))
          {
            if (graphics)
            {
              // Graphics stuff
              if (j>=0x40 && j<0x60) // Capitals exception
                text(fromCharCode(j),colAddress,textRow);
              else
              {
                float h=cellWidth/2; // half
                float t=cellHeight/3; // third  
                float g=1.0;  // separated gap            
                if (contiguousGraphics)
                  g=0.0;
                // text("X",colAddress,textRow);
                if ((j & 0x01)!=0) rect(colAddress,      rowAddress, h-g,t-g);
                if ((j & 0x02)!=0) rect(colAddress+h,    rowAddress, h-g,t-g);
                if ((j & 0x04)!=0) rect(colAddress,    rowAddress+t, h-g,t-g);
                if ((j & 0x08)!=0) rect(colAddress+h,  rowAddress+t, h-g,t-g);
                if ((j & 0x10)!=0) rect(colAddress,  rowAddress+t+t, h-g,t-g);
                if ((j & 0x40)!=0) rect(colAddress+h,rowAddress+t+t, h-g,t-g);
              }            
            }
            else // Normal text
            {
              //fill(255);
              text(fromCharCode(j),colAddress,textRow);
              // if (doubleHeight) text(String.fromCharCode(j),(int)colAddress,(int)textRow+1);
            }
          }
      } // switch character
    } // for each character
    if (doubleHeight)
    {
      // Copy regions must not overlap, so we need to do this in two steps
      int x0=0;
      int ya=int(r*cellHeight);
      int dx=int(ttxWidth);
      int dh=int(cellHeight);
      //println("Row="+r+" cellh="+cellHeight+" Move "+x0+" "+ya+" "+dx+" "+dh+" to "+
      //     x0+" "+(ya+dh)+" "+dx+" "+dh);
      
      if (droidMode)
      {
        copy(x0, ya+dh, dx, dh,
             x0,    ya, dx, dh);  // Copy the text down one line
        copy(x0,    ya, dx, dh+dh,  
             x0, ya+dh, dx, dh); // Copy and scalex2 the line back
      }
      else
      {
         // Good ones here
         copy(x0,    ya, dx, dh,
             x0, ya+dh, dx, dh); // Works on Java but not Android
        copy(x0, ya+dh, dx, dh,
             x0,    ya, dx, dh*2);
      }
    }
  } // drawRow
  
  /**
   * Forwards a mouse press to the teletext page
   * \param x : mouse coordinate
   * \param y : mouse coordinate
   * \return x : 0, or a valid page number
   */
  int mousePressed(int x, int y)
  {
    int row;
    int col;
    int link=0;
    // What row/column address are we clicking?
    col=int(x/cellWidth);
    row=int((y*25)/ttxHeight);
    // println("Checking mouse ("+col+","+row+"), size="+m_links.size());
    for (int i=0;i<m_links.size();i++)
    {
      link=m_links.get(i).GetLink(col,row,m_subpageList[m_CarouselIndex]);
      if (link>0)
      {
        // println("Found link "+hex(link));
        break;
      }
    }
    return link;
  }
  
  // Fastext links are in their own array
  int GetFastextLink(int link)
  {
    // println("[GetFastextLink] index="+link+", link="+fastextLinks[link]);
    if (link>6) return 0; // Out of range
    return fastextLinks[link];
  }  
  
  int GetLanguage()
  {
    int language;
    language=(m_PageStatus >> 7) & 0x07;
    return language;
  }
  

} // </TTX>

// Deals with page numbers as active links
class TTXLink
{
  private int m_row;  // Row number
  private int m_col;  // Column. (First character of link)
  private int m_link; // A teletext page number
  private int m_page; // The subpage that this link is on
  
  TTXLink(int col, int row, int link, int page)
  {
    // println("[TTXLink] adding link "+hex(link,3)+" on subpage "+hex(page,5));
    if (row<1) {row=1;}
    if (row>25) {row=25;}
    if (col<0) {col=0;}
    if (col>39) {col=39;}
    if (link<0x100) {link=0x100;}
    if (link>0x899) {link=0x899;}
    m_row=row;
    m_col=col;
    m_link=link;
    m_page=page;
  }
  
  // If the incoming click matches, return the link
  // otherwise return 0
  int GetLink(int col, int row, int subPage)
  {
    // println("[GetLink]col="+col+"row="+row+" page="+hex(subPage,5)+" This link ("+m_col+", "+m_row+", "+hex(m_page,5));
    if (row!=m_row) return 0;
    if (col<m_col || col>(m_col+3)) return 0;
    // println("[GetLink] matching subPage: "+subPage+" "+m_page);
    if (subPage!=m_page) return 0;
    return m_link;
  }
  
  
} // </TTXLink>

/** mapChar maps special characters
 * currently only maps English.
 * Todo: Change everything to returns. It is probably slightly faster
 */
char mapChar(int code)
{
  char ch=char(code & 0x7f);
  // More language mappings needed including Greek
  if (ch==0x7f) return 0xe65f; // 7/F Bullet (rectangle block)  
  // English mappings
  switch (ttx.GetLanguage())
  {
    case 4 : // German
        if (ch=='#')  return '#';    // 2/3 # is not mapped
        if (ch=='$')  return 0x0024; // 2/4 Dollar sign not mapped
        if (ch=='@')  return 0x00a7; // 4/0 Section sign
        if (ch=='[')  return 0x00c4; // 5/B A umlaut
        if (ch=='\\') return 0x00d6; // 5/C O umlaut
        if (ch==']')  return 0x00dc; // 5/D U umlaut
        if (ch=='^')  return '^';    // 5/E Caret (not mapped)
        if (ch=='_')  return 0x005f; // 5/F Underscore (not mapped)
        if (ch=='`')  return 0x00b0; // 6/0 Masculine ordinal indicator
        if (ch=='{')  return 0x00e4; // 7/B a umlaut
        if (ch=='|')  return 0x00f6; // 7/C o umlaut
        if (ch=='}')  return 0x00fc; // 7/D u umlaut
        if (ch=='~')  return 0x00df; // 7/E SS
        break;          
     case 1 : // French
        if (ch=='#')  ch=0x00e9; // 2/3 e acute
        if (ch=='$')  ch=0x00ef; // 2/4 i umlaut
        if (ch=='@')  ch=0x00e0; // 4/0 a grave
        if (ch=='[')  ch=0x00eb; // 5/B e umlaut
        if (ch=='\\') ch=0x00ea; // 5/C e circumflex
        if (ch==']')  ch=0x00f9; // 5/D u grave
        if (ch=='^')  ch=0x00ee; // 5/E i circumflex
        if (ch=='_')  ch='#';    // 5/F #
        if (ch=='`')  ch=0x00e8; // 6/0 e grave
        if (ch=='{')  ch=0x00e2; // 7/B a circumflex
        if (ch=='|')  ch=0x00f4; // 7/C o circumflex
        if (ch=='}')  ch=0x00fb; // 7/D u circumflex
        if (ch=='~')  ch=0x00e7; // 7/E c cedilla
        break;
    case 2 : // Swedish
        if (ch=='#')  ch='#'; // 2/3 hash
        if (ch=='$')  ch=0x00a4; // 2/4 currency bug
        if (ch=='@')  ch=0x00c9; // 4/0 E acute
        if (ch=='[')  ch=0x00c4; // 5/B A umlaut
        if (ch=='\\') ch=0x00d4; // 5/C O umlaut
        if (ch==']')  ch=0x00c5; // 5/D A ring
        if (ch=='^')  ch=0x00dc; // 5/E U umlaut
        if (ch=='_')  ch=0x005f; // 5/F Underscore (not mapped)
        if (ch=='`')  ch=0x00e9; // 6/0 e acute
        if (ch=='{')  ch=0x00e4; // 7/B a umlaut
        if (ch=='|')  ch=0x00d6; // 7/C o umlaut
        if (ch=='}')  ch=0x00e5; // 7/D a ring
        if (ch=='~')  ch=0x00fc; // 7/E u umlaut
        break;
    case 3 : // Czech/Slovak
        if (ch=='#')  ch='#';    // 2/3 hash
        if (ch=='$')  ch=0x016f; // 2/4 u ring
        if (ch=='@')  ch=0x010d; // 4/0 c caron
        if (ch=='[')  ch=0x0165; // 5/B t caron
        if (ch=='\\') ch=0x017e; // 5/C z caron
        if (ch==']')  ch=0x00fd; // 5/D y acute
        if (ch=='^')  ch=0x00ed; // 5/E i acute
        if (ch=='_')  ch=0x0159; // 5/F r caron        
        if (ch=='`')  ch=0x00e9; // 6/0 e acute
        if (ch=='{')  ch=0x00e1; // 7/B a acute
        if (ch=='|')  ch=0x011b; // 7/C e caron
        if (ch=='}')  ch=0x00fa; // 7/D u acute
        if (ch=='~')  ch=0x0161; // 7/E s caron
        break;
    case 5 : // Spanish/Portuguese
        if (ch=='#')  ch=0x00e7; // 2/3 c cedilla
        if (ch=='$')  ch='$';    // 2/4 Dollar sign not mapped
        if (ch=='@')  ch=0x00a1; // 4/0 inverted exclamation mark
        if (ch=='[')  ch=0x00e1; // 5/B a acute
        if (ch=='\\') ch=0x00e9; // 5/C e acute
        if (ch==']')  ch=0x00ed; // 5/D i acute
        if (ch=='^')  ch=0x00f3; // 5/E o acute
        if (ch=='_')  ch=0x00fa; // 5/F u acute
        if (ch=='`')  ch=0x00bf; // 6/0 Inverted question mark
        if (ch=='{')  ch=0x00fc; // 7/B u umlaut
        if (ch=='|')  ch=0x00f1; // 7/C n tilde
        if (ch=='}')  ch=0x00e8; // 7/D e grave
        if (ch=='~')  ch=0x00e0; // 7/E a grave
        break;
    case 6 : // Italian
        if (ch=='#')  ch=0x00a3; // 2/3 Pound
        if (ch=='$')  ch='$';    // 2/4 Dollar sign not mapped
        if (ch=='@')  ch=0x00e9; // 4/0 e acute
        if (ch=='[')  ch=0x00b0; // 5/B ring
        if (ch=='\\') ch=0x00e7; // 5/C c cedilla
        if (ch==']')  ch=0x2192; // 5/D right arrow
        if (ch=='^')  ch=0x2191; // 5/E up arrow
        if (ch=='_')  ch='#';    // 5/F hash
        if (ch=='`')  ch=0x00f9; // 6/0 u grave
        if (ch=='{')  ch=0x00e0; // 7/B a grave
        if (ch=='|')  ch=0x00f2; // 7/C o grave
        if (ch=='}')  ch=0x00e8; // 7/D e grave
        if (ch=='~')  ch=0x00ec; // 7/E i grave
        break;        
    case 0:; // English
    default:
      if (ch=='#') return '£';
      if (ch=='[')  return char(0x2190); // 5/B Left arrow.
      if (ch=='\\') return char(0xbd);   // 5/C Half
      if (ch==']')   return char(0x2192); // 5/D Right arrow.
      if (ch=='^')  return char(0x2191); // 5/E Up arrow.
      if (ch=='_')  return char(0x0023); // 5/F Underscore is hash sign
      if (ch=='`')  return char(0x2014); // 6/0 Centre dash. The full width dash e731
      if (ch=='{')  return char(0xbc);   // 7/B Quarter
      if (ch=='|')  return char(0x2016); // 7/C Double pipe
      if (ch=='}')  return char(0xbe);   // 7/D Three quarters
      if (ch=='~')  return char(0x00f7); // 7/E Divide      
  }
  return ch;
}

// Java/Javascript compatibility

/**** THIS SECTION FOR JAVASCRIPT
/**/
char fromCharCode(int code)
{
  code=mapChar(code);  
  return String.fromCharCode(code); // Javascript
}

int charCodeAt(String ch, int loc)
{
  return ch.charCodeAt(loc);
}
/**/


/**** THIS SECTION FOR JAVA 
/* *

char fromCharCode(int code)
{
  code=mapChar(code);
  return char(code);
}

int charCodeAt(String ch, int loc)
{
  if (loc>=ch.length())
    return 0;
  return ch.charAt(loc);
}
/**/
