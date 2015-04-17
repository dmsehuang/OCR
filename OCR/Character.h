//
//  Character.h
//  OCR
//
//  Created by huijinghuang on 4/16/15.
//  Copyright (c) 2015 huijinghuang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface Character : NSObject

@property (nonatomic, strong) NSMutableArray* pixels_x;
@property (nonatomic, strong) NSMutableArray* pixels_y;
@property (nonatomic) NSInteger left;
@property (nonatomic) NSInteger right;
@property (nonatomic) NSInteger top;
@property (nonatomic) NSInteger bottom;

-(UIImage *) getCharacterImage;
-(NSString *) getCharacter;

@end
