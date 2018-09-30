//
//  RNCharacterView.h
//  RNCharacterView
//

#import <UIKit/UIKit.h>
#import <React/RCTView.h>
#import <React/RCTBridgeModule.h>


@interface RNCharacterView : UIView

- (void)animateStrokes;
@property (nonatomic, copy) RCTBubblingEventBlock onComplete;

@end
