//
//  RNCharacterView.h
//  RNCharacterView
//

#import <UIKit/UIKit.h>
#import "RCTBridgeModule.h"


@interface RNCharacterView : UIView

- (void)animateCharacters:(NSString *)characters;
- (void)animateStrokes;

@end
