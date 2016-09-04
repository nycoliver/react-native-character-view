#import "RNCharacterViewManager.h"
#import "RNCharacterView.h"

#import "RCTViewManager.h"

@interface RNCharacterViewManager()
@property RNCharacterView *characterView;
@end

@implementation RNCharacterViewManager

- (instancetype)init
{
    if (!self)
        self = [super init];
    self.characterView = [[RNCharacterView alloc] init];
    return self;
}

- (UIView *)view
{
    return self.characterView;
}

RCT_EXPORT_MODULE()


RCT_EXPORT_METHOD(animateStrokes)
{
    [self.characterView animateStrokes];
}

RCT_EXPORT_VIEW_PROPERTY(character, NSString *)
RCT_EXPORT_VIEW_PROPERTY(quiz, BOOL)


@end
  