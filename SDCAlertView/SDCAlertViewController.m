//
//  SDCAlertViewController.m
//  SDCAlertView
//
//  Created by Scott Berrevoets on 11/5/13.
//  Copyright (c) 2013 Scotty Doesn't Code. All rights reserved.
//

#import "SDCAlertViewController.h"

#import "RBBSpringAnimation.h"
#import "SDCAlertView.h"
#import "SDCAlertViewContentView.h"
#import "SDCAlertViewBackgroundView.h"

#import "UIView+SDCAutoLayout.h"

static CGFloat 			const SDCAlertViewShowingAnimationScale = 1.26;
static CGFloat 			const SDCAlertViewDismissingAnimationScale = 0.84;
static CFTimeInterval	const SDCAlertViewSpringAnimationDuration = 0.5058237314224243;
static CGFloat			const SDCAlertViewSpringAnimationDamping = 500;
static CGFloat			const SDCAlertViewSpringAnimationMass = 3;
static CGFloat			const SDCAlertViewSpringAnimationStiffness = 1000;
static CGFloat			const SDCAlertViewSpringAnimationVelocity = 0;

@interface UIWindow (SDCAlertView)
+ (UIWindow *)sdc_alertWindow;
@end

@interface RBBSpringAnimation (SDCAlertView)
+ (RBBSpringAnimation *)sdc_alertViewSpringAnimationForKey:(NSString *)key;
@end


@interface SDCAlertView (SDCAlertViewPrivate)
@property (nonatomic, strong) SDCAlertViewBackgroundView *alertBackgroundView;
@property (nonatomic, strong) SDCAlertViewContentView *alertContentView;
@property (nonatomic, strong) UIToolbar *toolbar;

- (void)willBePresented;
- (void)didGetPresented;
@end

@interface SDCAlertViewController ()
@property (nonatomic, strong) UIWindow *previousWindow;
@property (nonatomic, strong) UIView *rootView;
@property (nonatomic, strong) UIView *backgroundColorView;
@property (nonatomic, strong) NSMutableOrderedSet *alertViews;
@end

@implementation SDCAlertViewController

+ (instancetype)currentController {
	UIViewController *currentController = [[UIWindow sdc_alertWindow] rootViewController];
	
	if ([currentController isKindOfClass:[SDCAlertViewController class]])
		return (SDCAlertViewController *)currentController;
	else
		return [[self alloc] init];
}

- (instancetype)init {
	self = [super init];
	
	if (self) {
		_alertViews = [[NSMutableOrderedSet alloc] init];
		[self initializeWindow];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];
	}
	
	return self;
}

- (void)initializeWindow {
	self.previousWindow = [[UIApplication sharedApplication] keyWindow];
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.rootViewController = self;
	self.window.windowLevel = UIWindowLevelAlert;
	
	self.rootView = [[UIView alloc] initWithFrame:self.window.bounds];
	[self.window addSubview:self.rootView];
	
	self.backgroundColorView = [[UIView alloc] initWithFrame:self.rootView.bounds];
	self.backgroundColorView.backgroundColor = [UIColor colorWithWhite:0 alpha:.4];
	self.backgroundColorView.layer.opacity = 1.0;
	[self.backgroundColorView setTranslatesAutoresizingMaskIntoConstraints:NO];
	[self.rootView addSubview:self.backgroundColorView];
	
	[self.rootView sdc_horizontallyCenterInSuperview];
}

#pragma mark - Showing/Hiding

- (void)keyboardWillShow:(NSNotification *)notification {
	NSDictionary *userInfo = [notification userInfo];
	NSValue *keyboardFrameValue = userInfo[UIKeyboardFrameEndUserInfoKey];
	CGRect keyboardFrame = [keyboardFrameValue CGRectValue];
	
	self.rootView.frame = CGRectMake(0, 0, CGRectGetWidth(self.rootView.frame), CGRectGetHeight(self.rootView.frame) - CGRectGetHeight(keyboardFrame));
}

- (void)keyboardDidHide:(NSNotification *)notification {
	self.rootView.frame = self.window.frame;
}

- (void)changeActiveWindowIfNeeded {
	if ([self.alertViews count] > 0 && [[UIApplication sharedApplication] keyWindow] != self.window) {
		[[[UIApplication sharedApplication] keyWindow] setTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
		[self.window makeKeyAndVisible];
		[self.window bringSubviewToFront:self.rootView];
	} else if ([self.alertViews count] == 0 && [[UIApplication sharedApplication] keyWindow] != self.previousWindow) {
		self.previousWindow.tintAdjustmentMode = UIViewTintAdjustmentModeAutomatic;
		[self.previousWindow makeKeyAndVisible];
		self.window = nil;
	}
}

- (void)showAlert:(SDCAlertView *)alert animated:(BOOL)animated {
	[self.alertViews addObject:alert];
	[self.rootView addSubview:alert];
	
	[self changeActiveWindowIfNeeded];
	
	if ([self.alertViews count] > 1) {
		SDCAlertView *previousAlert = self.alertViews[0];
		CATransform3D transformFrom = CATransform3DMakeScale(1, 1, 1);
		CATransform3D transformTo = CATransform3DMakeScale(SDCAlertViewDismissingAnimationScale, SDCAlertViewDismissingAnimationScale, 1);
		
		[self animateAlertTransform:previousAlert from:transformFrom to:transformTo];
		[self animateAlertOpacity:previousAlert from:1 to:0];
	}
	
	[alert willBePresented];
	
	if (animated) {
		[self animateUsingBlock:^{
			CATransform3D transformFrom = CATransform3DMakeScale(SDCAlertViewShowingAnimationScale, SDCAlertViewShowingAnimationScale, 1);
			CATransform3D transformTo = CATransform3DMakeScale(1, 1, 1);
			[self animateAlertTransform:alert from:transformFrom to:transformTo];
			
			RBBSpringAnimation *opacityAnimation = [self animateAlertOpacity:alert from:0 to:1];
			
			if ([self.alertViews count] == 1) {
				self.backgroundColorView.layer.opacity = 1;
				[self.backgroundColorView.layer addAnimation:opacityAnimation forKey:@"opacity"];
			}
		} completionHandler:^{
			[alert didGetPresented];
		}];
	} else {
		[alert didGetPresented];
	}
}

- (void)dismissAlert:(SDCAlertView *)alert animated:(BOOL)animated completion:(void (^)(void))completionHandler {
	[alert resignFirstResponder];
	[self.alertViews removeObject:alert];
	
	void (^dismissBlock)() = ^{
		[alert removeFromSuperview];
		[self changeActiveWindowIfNeeded];
		
		if (completionHandler)
			completionHandler();
	};
	
	if (animated) {
		[self animateUsingBlock:^{
			CATransform3D transformFrom = CATransform3DMakeScale(1, 1, 1);
			CATransform3D transformTo = CATransform3DMakeScale(SDCAlertViewDismissingAnimationScale, SDCAlertViewDismissingAnimationScale, 1);
			
			[self animateAlertTransform:alert from:transformFrom to:transformTo];
			RBBSpringAnimation *opacityAnimation = [self animateAlertOpacity:alert from:1 to:0];
			
			if ([self.alertViews count] == 0) {
				self.backgroundColorView.layer.opacity = 0;
				[self.backgroundColorView.layer addAnimation:opacityAnimation forKey:@"opacity"];
			} else {
				[[self currentAlert] setNeedsUpdateConstraints];
				CATransform3D transformFrom = CATransform3DMakeScale(SDCAlertViewDismissingAnimationScale, SDCAlertViewDismissingAnimationScale, 1);
				CATransform3D transformTo = CATransform3DMakeScale(1, 1, 1);
				[self animateAlertTransform:[self currentAlert] from:transformFrom to:transformTo];
				
				[self animateAlertOpacity:[self currentAlert] from:0 to:1];
			}
		} completionHandler:dismissBlock];
	} else {
		dismissBlock();
	}
}

- (SDCAlertView *)currentAlert {
	return [self.alertViews lastObject];
}

#pragma mark - Animations

- (void)animateUsingBlock:(void(^)(void))animations completionHandler:(void(^)(void))completionHandler {
	[CATransaction begin];
	[CATransaction setCompletionBlock:completionHandler];
	animations();
	[CATransaction commit];
}

- (RBBSpringAnimation *)animateAlertTransform:(SDCAlertView *)alert from:(CATransform3D)transformFrom to:(CATransform3D)transformTo {
	RBBSpringAnimation *transformAnimation = [RBBSpringAnimation sdc_alertViewSpringAnimationForKey:@"transform"];
	transformAnimation.fromValue = [NSValue valueWithCATransform3D:transformFrom];
	transformAnimation.toValue = [NSValue valueWithCATransform3D:transformTo];
	
	alert.layer.transform = transformTo;
	[alert.layer addAnimation:transformAnimation forKey:@"transform"];
	
	return transformAnimation;
}

- (RBBSpringAnimation *)animateAlertOpacity:(SDCAlertView *)alert from:(CGFloat)fromValue to:(CGFloat)toValue {
	RBBSpringAnimation *opacityAnimation = [RBBSpringAnimation sdc_alertViewSpringAnimationForKey:@"opacity"];
	opacityAnimation.fromValue = @(fromValue);
	opacityAnimation.toValue = @(toValue);
	
	alert.alertBackgroundView.layer.opacity = toValue;
	alert.alertContentView.layer.opacity = toValue;
	alert.toolbar.layer.opacity = toValue;
	
	[alert.alertBackgroundView.layer addAnimation:opacityAnimation forKey:@"opacity"];
	[alert.alertContentView.layer addAnimation:opacityAnimation forKey:@"opacity"];
	[alert.toolbar.layer addAnimation:opacityAnimation forKey:@"opacity"];
	
	return opacityAnimation;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation RBBSpringAnimation (SDCAlertView)

+ (RBBSpringAnimation *)sdc_alertViewSpringAnimationForKey:(NSString *)key {
	RBBSpringAnimation *animation = [[RBBSpringAnimation alloc] init];
	animation.duration = SDCAlertViewSpringAnimationDuration;
	animation.damping = SDCAlertViewSpringAnimationDamping;
	animation.mass = SDCAlertViewSpringAnimationMass;
	animation.stiffness = SDCAlertViewSpringAnimationStiffness;
	animation.velocity = SDCAlertViewSpringAnimationVelocity;
	
	return animation;
}

@end

@implementation UIWindow(SDCAlertView)

+ (UIWindow *)sdc_alertWindow {
	NSArray *windows = [[UIApplication sharedApplication] windows];
	NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(UIWindow *window, NSDictionary *bindings) {
		return [window.rootViewController isKindOfClass:[SDCAlertViewController class]];
	}];
	
	NSArray *alertWindows = [windows filteredArrayUsingPredicate:predicate];
	NSAssert([alertWindows count] <= 1, @"At most one alert window should be active at any point");
	
	return [alertWindows firstObject];
}

@end
