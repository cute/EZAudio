//
//  PlayFileViewController.m
//  EZAudioPlayFileExample
//
//  Created by Syed Haris Ali on 12/13/13.
//  Copyright (c) 2013 Syed Haris Ali. All rights reserved.
//

#import "PlayFileViewController.h"

@interface PlayFileViewController ()

@end

@implementation PlayFileViewController
@synthesize audioFile;
@synthesize audioPlot;
@synthesize eof = _eof;

#pragma mark - Initialization
-(id)init {
  self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
  if(self){
    [self initializeViewController];
  }
  return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
  if(self){
    [self initializeViewController];
  }
  return self;
}

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
  if(self){
    [self initializeViewController];
  }
  return self;
}

#pragma mark - Initialize View Controller
-(void)initializeViewController {
}

#pragma mark - Customize the Audio Plot
-(void)awakeFromNib {
  
  /*
   Customizing the audio plot's look
   */
  // Background color
  self.audioPlot.backgroundColor = [NSColor colorWithCalibratedRed: 0.993 green: 0.881 blue: 0.751 alpha: 1];
  // Waveform color
  self.audioPlot.color           = [NSColor colorWithCalibratedRed: 0.219 green: 0.234 blue: 0.29 alpha: 1];
  // Plot type
  self.audioPlot.plotType        = EZPlotTypeBuffer;
  // Fill
  self.audioPlot.shouldFill      = YES;
  // Mirror
  self.audioPlot.shouldMirror    = YES;
  
  /*
   Try opening the sample file
   */
  [self openFileWithFilePathURL:[NSURL fileURLWithPath:kAudioFileDefault]];
  
}

#pragma mark - Actions
-(void)changePlotType:(id)sender {
  NSInteger selectedSegment = [sender selectedSegment];
  switch(selectedSegment){
    case 0:
      [self drawBufferPlot];
      break;
    case 1:
      [self drawRollingPlot];
      break;
    default:
      break;
  }
}

-(void)openFile:(id)sender {
  NSOpenPanel* openDlg = [NSOpenPanel openPanel];
  openDlg.canChooseFiles = YES;
  openDlg.canChooseDirectories = NO;
  openDlg.delegate = self;
  if( [openDlg runModal] == NSOKButton ){
    NSArray *selectedFiles = [openDlg URLs];
    [self openFileWithFilePathURL:selectedFiles.firstObject];
  }
}

-(void)play:(id)sender {
  if( ![[EZOutput sharedOutput] isPlaying] ){
    if( self.eof ){
      [self.audioFile seekToFrame:0];
    }
    [EZOutput sharedOutput].outputDataSource = self;
    [[EZOutput sharedOutput] startPlayback];
  }
  else {
    [EZOutput sharedOutput].outputDataSource = nil;
    [[EZOutput sharedOutput] stopPlayback];
  }
}

#pragma mark - Action Extensions
/*
 Give the visualization of the current buffer (this is almost exactly the openFrameworks audio input eample)
 */
-(void)drawBufferPlot {
  // Change the plot type to the buffer plot
  self.audioPlot.plotType = EZPlotTypeBuffer;
  // Don't mirror over the x-axis
  self.audioPlot.shouldMirror = NO;
  // Don't fill
  self.audioPlot.shouldFill = NO;
}

/*
 Give the classic mirrored, rolling waveform look
 */
-(void)drawRollingPlot {
  self.audioPlot.plotType = EZPlotTypeRolling;
  self.audioPlot.shouldFill = YES;
  self.audioPlot.shouldMirror = YES;
}

-(void)openFileWithFilePathURL:(NSURL*)filePathURL {
  
  // Stop playback
  [[EZOutput sharedOutput] stopPlayback];
  
  self.audioFile                 = [EZAudioFile audioFileWithURL:filePathURL];
  self.eof                       = NO;
  self.filePathLabel.stringValue = filePathURL.lastPathComponent;
  
  // The EZAudioFile provides convenience methods to optimize the waveform drawings. It will choose a proper window to iterate through the file that will generate roughly ~2048 buffers and so 2048 points on the waveform graph. This ensures that we get a good looking plot for both very small and very large files
  UInt32 frameRate = [self.audioFile recommendedDrawingFrameRate];
  UInt32 buffers   = [self.audioFile minBuffersWithFrameRate:frameRate];
  
  // Take a snapshot of each buffer through the audio file to form the waveform
  __block float rms;
  float data[buffers];
  for( int i = 0; i < buffers; i++ ){
    
    // Allocate a buffer list to hold the audio file's data
    AudioBufferList *bufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    UInt32          bufferSize;
    BOOL            eof;
    
    // Read some data from the audio file (the audio file internally maintains the seek position you're at). You can manually seek to whatever position in the audio file using the seekToFileOffset: function on the EZAudioFile.
    [self.audioFile readFrames:frameRate
               audioBufferList:bufferList
                    bufferSize:&bufferSize
                           eof:&eof];
    
    // Get the RMS of the buffer
    rms = [EZAudio RMS:bufferList->mBuffers[0].mData length:bufferSize];
    data[i] = rms;
    
    // Since we malloc'ed, we should cleanup
    [EZAudio freeBufferList:bufferList];
    
  }
  
  // Seek the audio file back to the beginning if we're performing playback
  [self.audioFile seekToFrame:0];
  
  // Update the audio plot once all the snapshots have been taken
  [self.audioPlot updateBuffer:data withBufferSize:buffers];
  
}

-(void)updateAudioPlotWithBufferList:(AudioBufferList*)bufferList
                      withBufferSize:(UInt32)bufferSize {
  dispatch_async(dispatch_get_main_queue(), ^{
    if( [EZOutput sharedOutput].isPlaying ){
      [self.audioPlot updateBuffer:bufferList->mBuffers[0].mData withBufferSize:bufferSize];
    }
  });
}

#pragma mark - EZOutputDataSource
-(AudioBufferList *)output:(EZOutput *)output
 needsBufferListWithFrames:(UInt32)frames
            withBufferSize:(UInt32 *)bufferSize {
  if( self.audioFile ){
    
    // Reached the end of the file
    if( self.eof ){
      return nil;
    }
    
    // Allocate a buffer list to hold the file's data
    AudioBufferList *bufferList = (AudioBufferList*)malloc(sizeof(AudioBufferList));
    BOOL eof;
    [self.audioFile readFrames:frames
               audioBufferList:bufferList
                    bufferSize:bufferSize
                           eof:&eof];
    self.eof = eof;
    
    // Reached the end of the file on the last read
    if( eof ){
      [EZAudio freeBufferList:bufferList];
      return nil;
    }
    
    // Haven't reached the end of the file, seek reading and update plot
    else {
      
      // To do any additional updating it must happen on the main thread
      dispatch_async(dispatch_get_main_queue(), ^{
        
        // Update the waveform
        if( [EZOutput sharedOutput].isPlaying ){
          [self.audioPlot updateBuffer:bufferList->mBuffers[0].mData withBufferSize:*bufferSize];
        }
        
        // Free the resources
        [EZAudio freeBufferList:bufferList];
        
      });
    
    }
    return bufferList;
  }
  return nil;
}

-(AudioStreamBasicDescription)outputHasAudioStreamBasicDescription:(EZOutput *)output {
  return self.audioFile.clientFormat;
}

#pragma mark - NSOpenSavePanelDelegate
/**
 Here's an example how to filter the open panel to only show the supported file types by the EZAudioFile (which are just the audio file types supported by Core Audio).
 */
-(BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename {
  NSString* ext = [filename pathExtension];
  if ([ext isEqualToString:@""] || [ext isEqualToString:@"/"] || ext == nil || ext == NULL || [ext length] < 1) {
    return YES;
  }
  NSArray *fileTypes = [EZAudioFile supportedAudioFileTypes];
  NSEnumerator* tagEnumerator = [fileTypes objectEnumerator];
  NSString* allowedExt;
  while ((allowedExt = [tagEnumerator nextObject]))
  {
    if ([ext caseInsensitiveCompare:allowedExt] == NSOrderedSame)
    {
      return YES;
    }
  }
  return NO;
}

@end