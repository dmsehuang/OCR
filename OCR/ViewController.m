//
//  ViewController.m
//  OCR
//
//  Created by huijinghuang on 4/11/15.
//  Copyright (c) 2015 huijinghuang. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // change the image name to your image
    //UIImage* img = [UIImage imageNamed:@"1_sample_complete.png"];
    UIImage* img = [UIImage imageNamed:@"2_sample_part.png"];
    //UIImage* img = [UIImage imageNamed:@"3_sample_color.png"];
    //UIImage* img = [UIImage imageNamed:@"4_sample_jack-ma.png"];
    //UIImageView* initImgView = [[UIImageView alloc] initWithImage:img];
    //[self.view addSubview:initImgView];

    UIImage* BWImg = [self convertImageTOBlackNWhite:img];
    UIImageView* BWImgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 45, BWImg.size.width, BWImg.size.height)];
    [BWImgView setImage:BWImg];
    [self.view addSubview:BWImgView];
    //[self lineDetection:img];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(unsigned char *)UIImageToRGBA8:(UIImage*) image {
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    unsigned char* rawData = (unsigned char*) calloc(width * height * 4, sizeof(unsigned char));
    
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    NSUInteger bitsPerComponent = 8;
    CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(context);
    
    return rawData;
}

-(UIImage *)convertImageTOBlackNWhite:(UIImage *) image{
    #pragma line detection
    // line detection core algorithm
    
    // step 2 threshold the image
    unsigned char* rawData = [self UIImageToRGBA8:image];
    CGFloat threshold = 0.5;
    for (int i = 0; i < image.size.width * image.size.height * 4; i += 4) {
        if (rawData[i] + rawData[i+1] + rawData[i+2] < 255 * 3 * threshold) {
            rawData[i] = 0;
            rawData[i+1] = 0;
            rawData[i+2] = 0;
        } else {
            rawData[i] = 255;
            rawData[i+1] = 255;
            rawData[i+2] = 255;
        }
    }
    
    CGImageRef imageRef = [image CGImage];
    NSUInteger width = CGImageGetWidth(imageRef);
    NSUInteger height = CGImageGetHeight(imageRef);
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    
    // step 3 horizontal projection
    NSMutableArray* lines = [NSMutableArray arrayWithCapacity:height];
    bool top = false;
    int* horiArr = (int*) calloc(height, sizeof(int));
    for (int i = 0; i < height; i++) {
        int blackPixel = 0;
        for (int j = 0; j < width; j++) {
            NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
            if (rawData[index] == 0) {
                blackPixel++;
                //NSLog(@"black");
            }
        }
        horiArr[i] = blackPixel;
        UIView* lineView = [[UIView alloc] initWithFrame:CGRectMake(200, i, horiArr[i], 1)];
        lineView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:lineView];
        
        if (blackPixel > 0) {
            if (!top || i == height-1) {
                // last black pixel should also be in
                [lines addObject:[NSNumber numberWithInt:i]];
                // draw line to test
                /*
                for (int j = 0; j < width; j++) {
                    NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
                    rawData[index] = 255;
                    rawData[index+1] = 102;
                    rawData[index+2] = 102;
                }
                */
                top = true;
            }
        } else {
            if (top) {
                [lines addObject:[NSNumber numberWithInt:i]];
                /*
                for (int j = 0; j < width; j++) {
                    NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
                    rawData[index] = 255;
                    rawData[index+1] = 102;
                    rawData[index+2] = 102;
                }
                */
                top = false;
            }
        }
    }
    free(horiArr); // free memory after use
    
    // -- end of line detection core algorithm
    NSNumber* topLine = (NSNumber*)[lines objectAtIndex:2];
    NSNumber* bottomLine = (NSNumber*)[lines objectAtIndex:3];
    [self connectedComponentFromData:rawData withWidth:(int)width betweenTopLine:topLine andBottomLine:bottomLine];
    
    image = [self convertBitmapRGBA8ToUIImage:rawData withWidth:image.size.width withHeight:image.size.height];
    
    return image;
}

#pragma connected component algorithm
-(void) connectedComponentFromData:(unsigned char*)rawData withWidth:(int)width
                    betweenTopLine:(NSNumber*) topLine andBottomLine:(NSNumber*) bottomLine {
    // ------------- step 1 ----------------------//
    // ------------ assign label -----------------//
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = bytesPerPixel * width;
    
    // only test one line
    int top = [topLine intValue];
    int bottom = [bottomLine intValue];
    int height = bottom - top + 1;
    NSInteger labelArr[height][width]; // C style
    // init label array
    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            labelArr[i][j] = 0; // zero means not assigned
        }
    }
    NSInteger parent[width];
    
    int labelCount = 0; // label begins with 1
    
    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width; j++) {
            NSUInteger index = bytesPerRow * i + bytesPerPixel * j;
            if (rawData[index] == 255) continue; // skip white pixel
            
            // step 1.1: search for the min label
            NSInteger minLabel = 0; // 0 means can't find
            NSInteger xcorrd[4] = {i, i-1, i-1, i-1};
            NSInteger ycoord[4] = {j-1, j-1, j, j+1};
            for (int k = 0; k < 4; k++) {
                int x = (int) xcorrd[k];
                int y = (int) ycoord[k];
                if (labelArr[x][y] == 0) continue; // not assigned value yet
                if (minLabel == 0) minLabel = labelArr[x][y];
                else minLabel = minLabel < labelArr[x][y] ? minLabel : labelArr[x][y];
            }

            // step 1.2: assign value to current pixel
            if (minLabel == 0) {
                ++labelCount;
                labelArr[i][j] = labelCount;
                parent[labelCount] = labelCount; // set self as the parent
            } else {
                labelArr[i][j] = minLabel;
            }
            
            // step 1.3: update parent
            for (int k = 0; k < 4; k++) {
                int x = (int) xcorrd[k];
                int y = (int) ycoord[k];
                if (labelArr[x][y] == 0) continue;
                parent[labelArr[x][y]] = minLabel;
            }
        }
    }
    
    NSMutableString* test = [[NSMutableString alloc] initWithString:@"\n"];
    for (int i = 0; i < height; i++) {
        for (int j = 0; j < width/3; j++) {
            if (labelArr[i][j] == 0) {
                [test appendString:@"  "];
            } else {
                [test appendString:[NSString stringWithFormat:@"%02d", (int)labelArr[i][j]]];
            }
        }
        [test appendString:@"\n"];
    }
    NSLog(@"test result");
    NSLog(@"%@", test);
    
    // ------------- step 2 ----------------------//
    // ------------- merge label -----------------//
    
}

//PLEASE FIND THE BELOW CONVERSION METHODS FROM HERE
//https://gist.github.com/PaulSolt/739132

-(UIImage *) convertBitmapRGBA8ToUIImage:(unsigned char *) buffer withWidth:(int) width withHeight:(int) height
{
    size_t bufferLength = width * height * 4;
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, bufferLength, NULL);
    size_t bitsPerComponent = 8;
    size_t bitsPerPixel = 32;
    size_t bytesPerRow = 4 * width;
    
    CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
    
    if(colorSpaceRef == NULL)
    {
        NSLog(@"Error allocating color space");
        CGDataProviderRelease(provider);
        return nil;
    }
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
    CGColorRenderingIntent renderingIntent = kCGRenderingIntentDefault;
    
    CGImageRef iref = CGImageCreate(width,
                                    height,
                                    bitsPerComponent,
                                    bitsPerPixel,
                                    bytesPerRow,
                                    colorSpaceRef,
                                    bitmapInfo,
                                    provider, // data provider
                                    NULL,  // decode
                                    YES,   // should interpolate
                                    renderingIntent);
    
    uint32_t* pixels = (uint32_t*)malloc(bufferLength);
    
    if(pixels == NULL)
    {
        NSLog(@"Error: Memory not allocated for bitmap");
        CGDataProviderRelease(provider);
        CGColorSpaceRelease(colorSpaceRef);
        CGImageRelease(iref);
        return nil;
    }
    
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, bitsPerComponent, bytesPerRow, colorSpaceRef, bitmapInfo);
    if(context == NULL)
    {
        NSLog(@"Error context not created");
        free(pixels);
    }
    
    UIImage *image = nil;
    
    if(context)
    {
        CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, width, height), iref);
        CGImageRef imageRef = CGBitmapContextCreateImage(context);
        
        // Support both iPad 3.2 and iPhone 4 Retina displays with the correct scale
        if([UIImage respondsToSelector:@selector(imageWithCGImage:scale:orientation:)]) {
            float scale = [[UIScreen mainScreen] scale];
            image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
        } 
        else 
        {
            image = [UIImage imageWithCGImage:imageRef];
        }
        
        CGImageRelease(imageRef);
        CGContextRelease(context);
    }
    
    CGColorSpaceRelease(colorSpaceRef);
    CGImageRelease(iref);
    CGDataProviderRelease(provider);
    
    if(pixels) {
        free(pixels);
    }
    
    return image;
}

@end
