//
//  ViewController.m
//  Wanderlust
//
//  Created by Serdar Karatekin on 4/8/15.
//  Copyright (c) 2015 Serdar Karatekin. All rights reserved.
//

#import "ExplorePlacesViewController.h"
#import "APIClient.h"
#import "Macros.h"
#import "Place+Read.h"
#import "Place+Write.h"
#import "MapViewController.h"
#import "PlaceView.h"
#import "AppDelegate.h"
#import "FavoritePlacesViewController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <UIImageView+AFNetworking.h>
#import "ExplorePlacesCustomAnimator.h"


@interface ExplorePlacesViewController () <UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet CardsStackView *cardsStack;
@property (weak, nonatomic) PlaceView *cardOnTop;
@property (weak, nonatomic) IBOutlet UILabel *placeName;
@property (weak, nonatomic) IBOutlet UILabel *placeAddress;
@property (weak, nonatomic) IBOutlet UIButton *viewFavoritesButton;

@property (strong, nonatomic) NSMutableArray *places;

@end

@implementation ExplorePlacesViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (!self.places) {
        [self getPlaces];
    }
    
    // Set ourself as the navigation controller's delegate so we're asked for a transitioning object
    self.navigationController.delegate = self;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    // Stop being the navigation controller's delegate
    if (self.navigationController.delegate == self) {
        self.navigationController.delegate = nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - View Setup

- (void)setupView {
    self.placeName.numberOfLines = 2;
    self.placeName.minimumScaleFactor = 8.0 / self.placeName.font.pointSize;
    self.placeName.adjustsFontSizeToFitWidth = YES;
    
    self.placeAddress.numberOfLines = 2;
    self.placeAddress.minimumScaleFactor = 8.0 / self.placeName.font.pointSize;
    self.placeAddress.adjustsFontSizeToFitWidth = YES;
    
    self.cardsStack.delegate = self;
    self.cardsStack.dataSource = self;
    
    self.viewFavoritesButton.layer.cornerRadius = 5;
    
    // Don't show any text while items are loading
    self.placeAddress.text = @"";
    self.placeName.text = @"";
    
    // Assign navigation controller delegate
    self.navigationController.delegate = self;
}

#pragma mark - Get Data Helper Methods

- (void)getPlaces {
    
    [SVProgressHUD showWithStatus:@"Loading places..."];
    
    [[APIClient sharedInstance] getPlacesWithCompletionBlock:^(NSError *error, NSDictionary *response) {
        if (!error) {
            NSMutableArray *places = response[@"places"];
            self.places = places;
            DLog(@"Received %lu places from the API.", (unsigned long)places.count);
            
            [self.cardsStack reload];
            
            [SVProgressHUD showSuccessWithStatus:@"Success!"];
        } else {
            NSString *errorMessage = [NSString stringWithFormat:@"Error getting places: %@ %@", [error localizedDescription], [error userInfo]];
            [SVProgressHUD showErrorWithStatus:errorMessage];
            DLog(@"%@", errorMessage);
        }
    }];
}

- (void)setImageForImageView:(UIImageView *)view withPlace:(Place *)place {
    
    __weak UIImageView *weakImageView = view;
    NSURLRequest *request = [NSURLRequest requestWithURL:place.imageDownloadURL];
    [view setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
        UIImageView *strongImageView = weakImageView;
        if (!strongImageView) return;
        
        [UIView transitionWithView:strongImageView
                          duration:0.3
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
                            strongImageView.image = image;
                        }
                        completion:NULL];
        
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        DLog(@"Failed downloading image with error %@", [error localizedDescription]);
    }];
}

#pragma mark - CardsStackViewDataSource Methods

- (NSInteger)numberOfCardsOnStack:(CardsStackView *)stackView {
    // Only when we have data for places, we want the cards stack to load card views
    if (self.places) {
        return 5;
    } else {
        return 0;
    }
}

- (PannableCardView *)nextCardViewToShow:(CardsStackView *)stackView {
    NSUInteger randomIndex = arc4random() % [self.places count];
    Place *randomPlace = [self.places objectAtIndex:randomIndex];
//    DLog(@"Random place %@", randomPlace.title);
    
    PlaceView *newCardView = [[PlaceView alloc] initWithFrame:stackView.bounds];
    newCardView.delegate = stackView;
    newCardView.place = randomPlace;

    UIImageView *leftOverlayView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"nah_overlay"]];
    leftOverlayView.center = CGPointMake(stackView.bounds.size.width / 2, stackView.bounds.size.height / 2);
    newCardView.leftSwipeOverlayView = leftOverlayView;
    
    UIImageView *rightOverlayView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"yea_overlay"]];
    rightOverlayView.center = CGPointMake(stackView.bounds.size.width / 2, stackView.bounds.size.height / 2);
    newCardView.rightSwipeOverlayView = rightOverlayView;
    
    [self setImageForImageView:newCardView.imageView withPlace:randomPlace];
    
    return newCardView;
}

#pragma mark - CardsStackViewDelegate Methods

- (void)stackView:(CardsStackView *)stackView cardViewDidAppearOnTopOfStack:(PannableCardView *)cardView {
    PlaceView *placeView = (PlaceView *)cardView;

    self.placeName.text = placeView.place.title;
    self.placeAddress.text = placeView.place.address;
    self.cardOnTop = (PlaceView *)cardView;
}

- (void)stackView:(CardsStackView *)stackView didTapOnCardView:(PannableCardView *)cardView {
    [self performSegueWithIdentifier:@"MapViewControllerSegue" sender:self];
}

- (void)stackView:(CardsStackView *)stackView didSwipeCardViewLeft:(PannableCardView *)cardView {
    // Discard item from the list
    PlaceView *placeView = (PlaceView *)cardView;
    [self.places removeObject:placeView.place];
    
    // TODO: Delete item from core data as well
    
//    DLog(@"Number of places left %lu", (unsigned long)self.places.count);
}

- (void)stackView:(CardsStackView *)stackView didSwipeCardViewRight:(PannableCardView *)cardView {

    // Favorite the place that is right swiped
    
    PlaceView *placeView = (PlaceView *)cardView;
    Place *place = placeView.place;
    
    AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    [place setFavorited:YES inManagedObjectContext:delegate.managedObjectContext];
}

#pragma mark - UINavigationControllerDelegate methods

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC {
    
    // Check if we're transitioning from this view controller to the favorite places view controller
    // If so return our custom animator object for the transition animation
    if (fromVC == self && [toVC isKindOfClass:[FavoritePlacesViewController class]]) {
        return [[ExplorePlacesCustomAnimator alloc] init];
    } else {
        return nil;
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"MapViewControllerSegue"]) {

        MapViewController *mapVC = [segue destinationViewController];
        mapVC.place = self.cardOnTop.place;
    }
}

@end
