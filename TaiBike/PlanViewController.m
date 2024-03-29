//
//  PlanViewController.m
//  TaiBike
//
//  Created by Takeshi on 2014/5/28.
//  Copyright (c) 2014年 Takeshi. All rights reserved.
//

#import "PlanViewController.h"
#import "SelectPlanViewController.h"
#import "PlanTableView.h"
#import "PlanDisplayView.h"

@interface PlanViewController ()

@end

@implementation PlanViewController{
    UITableView *tableview;
    IBOutlet UIView *innerview;
    PlanTableView *planTableView;
    PlanDisplayView *planDisplayview;
    IBOutlet UIButton * stopbtn;
}

// 建立一個CLLocationCoordinate2D
CLLocationCoordinate2D mylocation,userLocation;
CLLocationManager *locationManager;
float user_NS,user_WE;
NSTimer* timer;
//建立一個 Dictionary
NSMutableDictionary *equpmentDictionary;
NSMutableDictionary *locationRecord;
bool recordflag = NO;
int recordIndex=0,recordCount;

PlanViewController *g_instance = nil;

+ (PlanViewController *)sharedInstance
{
    @synchronized(self) {
        if ( g_instance == nil ) {
            UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
            g_instance = [mainStoryboard instantiateViewControllerWithIdentifier: @"Plan"];
            g_instance.currentPlan = NULL;
        }
    }
    return g_instance;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self changeToPlanTableView];
}

- (void)changeToPlanTableView
{
    [planDisplayview removeFromSuperview];
    NSString* authKey = [ProfileViewController getAuthKey];
    NSLog(@"authKey : %@", authKey);
    
    NSDictionary* userInfo = [ProfileViewController getUserProfileWithAuthKey:authKey];
    
    ridePlans = [userInfo objectForKey:@"ridePlans"];
    
    planTableView = [[PlanTableView alloc]init];
    planTableView.ridePlans = ridePlans;
    planTableView.frame = CGRectMake(0, 210, 320, 358);
    [self.view addSubview:planTableView];
    [self.view bringSubviewToFront:innerview ];
}

- (void)changeToPlanDisplayView
{
    [planTableView removeFromSuperview];
    [stopbtn setHidden:NO];
    
    planDisplayview = [[PlanDisplayView alloc]init];
    
    NSMutableArray* data = [PlanViewController getPointWithPlanModel:_currentPlan];
    planDisplayview.data = data;
    planDisplayview.frame = CGRectMake(0, 210, 320, 358);
    [self.view addSubview:planDisplayview];
    [self.view bringSubviewToFront:innerview];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - SlideNavigationController Methods -

- (BOOL)slideNavigationControllerShouldDisplayLeftMenu
{
	return YES;
}

+ (NSMutableArray*)getPointWithPlanModel:(PlanModel*)model
{
    NSMutableArray *data = [[NSMutableArray alloc]init];
    NSMutableArray* points = model.points;
    
    for (NSMutableDictionary* point in points) {
        [data addObject:point];
    }
    
    NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
	[rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
	[rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    int size = data.count-1;
    size = size<0?0:size;
    for(int i=0;i<size;i++){
        for (int ii=i+1; ii<size+1; ii++) {
            // Convert the RFC 3339 date time string to an NSDate.
            NSDate *a = [rfc3339DateFormatter dateFromString:[(NSDictionary*)[data objectAtIndex:i] objectForKey:@"time"]];
            NSDate *b = [rfc3339DateFormatter dateFromString:[(NSDictionary*)[data objectAtIndex:ii] objectForKey:@"time"]];
            
            if ([a compare:b] == NSOrderedDescending) {
                NSObject *dataA = [data objectAtIndex:i];
                NSObject *dataB = [data objectAtIndex:ii];
                [data removeObjectAtIndex:i];
                [data insertObject:dataB atIndex:i];
                [data removeObjectAtIndex:ii];
                [data insertObject:dataA atIndex:ii];
            }
        }
    }
    return data;
}

- (IBAction)stop:(id)sender
{
    _currentPlan = nil;
    [stopbtn setHidden:YES];
    
    [self changeToPlanTableView];
    [_planLabel setText:@"目前沒有執行中的計劃"];
    [self recordbtn:nil];
}

+ (NSDate *)dateForRFC3339DateTimeString:(NSString *)rfc3339DateTimeString
{
	NSDateFormatter *rfc3339DateFormatter = [[NSDateFormatter alloc] init];
    
	[rfc3339DateFormatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.'SSS'Z'"];
	[rfc3339DateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
	// Convert the RFC 3339 date time string to an NSDate.
	NSDate *result = [rfc3339DateFormatter dateFromString:rfc3339DateTimeString];
	return result;
}

- (void)initLocation
{
    [self setLat:@"0"];
    [self setLongt:@"0"];
    
    [self loadLocationPlist];
    
    NSString *length = [equpmentDictionary valueForKey:@"length"];
    recordIndex = [length intValue];
    
    //[self startStandardUpdates];
    //timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateLoacation:) userInfo:nil repeats:YES]; //持續更新資料庫中使用者位置
    
    //map_view.delegate = self;
}

-(void)startStandardUpdates
{
    if (locationManager == nil){
        locationManager = [[CLLocationManager alloc] init];
        [self initLocation];
    }
    
    locationManager.delegate = self;
    locationManager.desiredAccuracy = 50;
    locationManager.distanceFilter = 50;
    [locationManager startUpdatingLocation];
}

-(void)stopStandardUpdates
{
    [locationManager stopUpdatingLocation];
    locationManager = nil;
}

-(void)updateLoacationPlist:(NSTimer*) timer
{
    //    [locationManager startUpdatingLocation];
    NSLog(@"updateLoacation  running...");
    
    NSMutableDictionary *data= [[NSMutableDictionary alloc]init];
    
    NSString *number = [NSString stringWithFormat:@"%i",recordCount++];
    [data setObject:number forKey:@"count"];
    
    NSString *dateString = [self getTimeNSString];
    [data setObject:dateString forKey:@"time"];
    
    if (_lat!=nil && _longt!=nil) {
    [data setObject:_lat forKey:@"latitude"];
    [data setObject:_longt forKey:@"longitude"];
    
    NSString *altStr = [NSString stringWithFormat:@"%f",_altitude];
    [data setObject:altStr forKey:@"altitude"];
    NSString *speedStr = [NSString stringWithFormat:@"%f",_speed];
    [data setObject:speedStr forKey:@"speed"];
    
    [locationRecord setObject:data forKey:number];
    }
}

-(NSString*)getTimeNSString
{
    NSDateFormatter *formatter;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"dd-MM-yyyy HH:mm:ss"];
    return [formatter stringFromDate:[NSDate date]];
}


- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation
{
    NSLog(@"locationManager running...");
    [self setLocationData:newLocation];
}

-(void)setLocationData:(CLLocation *)newLocation
{
    int degrees = newLocation.coordinate.latitude;
    double decimal = fabs(newLocation.coordinate.latitude - degrees);
    int minutes = decimal * 60;
    double seconds = decimal * 3600 - minutes * 60;
    _lat = [NSString stringWithFormat:@"%d° %d' %1.4f\"",
           degrees, minutes, seconds];
    
    degrees = newLocation.coordinate.longitude;
    decimal = fabs(newLocation.coordinate.longitude - degrees);
    minutes = decimal * 60;
    seconds = decimal * 3600 - minutes * 60;
    _longt = [NSString stringWithFormat:@"%d° %d' %1.4f\"",
             degrees, minutes, seconds];
    
    _altitude = newLocation.altitude;
    _speed = newLocation.speed;
}

-(void)loadLocationPlist
{
    //先從取出開始
    
    //初始化路徑
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains
                          (NSDocumentDirectory,NSUserDomainMask, YES)
                          objectAtIndex:0];
    
    //取得 plist 檔路徑
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"Location.plist"];
    
    //如果 Documents 文件夾中沒有 test.plist 的話，則從 project 目錄中载入 test.plist
    if (![[NSFileManager defaultManager] fileExistsAtPath:plistPath])
    {
        //        plistPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"plist"];
        NSLog(@"Load 'Loaction.plist' fail.");
        [self resetbtn:nil];
    }else{
        
        //將取得的 plist 內容載入至剛才建立的 Dictionary 中
        equpmentDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        NSLog(@"Load 'Loaction.plist' success.");
    }
}

-(void)storeLoctionPlist
{
    //取出剛才新增的 "PlayName"
    //    NSString *PlayName = [plistDictionary objectForKey:@"PlayName"];
    
    //再利用 NSLog 來查看剛才修改的 Dictionary
    //    NSLog(@"test plist:%@",plistDictionary);
    //    NSLog(@"PlayName:%@",PlayName);
    
    //取得儲存路徑
    NSString *SaveRootPath = [NSSearchPathForDirectoriesInDomains
                              (NSDocumentDirectory,NSUserDomainMask, YES)
                              objectAtIndex:0];
    NSString *SavePath = [SaveRootPath stringByAppendingPathComponent:@"Location.plist"];
    
    //將 Dictionary 儲存至指定的檔案
    [equpmentDictionary writeToFile:SavePath atomically:YES];
}

-(void)recordbtn:(id)sender
{
    if (recordflag) {
        recordflag=NO;
        [timer invalidate];
        [self stopStandardUpdates];
        
        //[recordbutton setTitle:@"開始記錄" forState:UIControlStateNormal];
        NSString *length = [NSString stringWithFormat:@"%i",recordCount-1];
        [locationRecord setObject:length forKey:@"length"];
        
        NSString *index = [NSString stringWithFormat:@"%i",recordIndex];
        [equpmentDictionary setObject:locationRecord forKey:index];
        [equpmentDictionary setObject:index forKey:@"length"];
        locationRecord =nil;
        [self storeLoctionPlist];
    }else{
        recordflag=YES;
        [self startStandardUpdates];
        
        //[recordbutton setTitle:@"停止記錄" forState:UIControlStateNormal];
        recordCount=1;
        locationRecord = [[NSMutableDictionary alloc]init];
        
        NSString *index = [NSString stringWithFormat:@"%i",++recordIndex];
        [locationRecord setObject:index forKey:@"index"];
        [locationRecord setObject:[self getTimeNSString] forKey:@"stert_time"];
        
        timer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(updateLoacationPlist:) userInfo:nil repeats:YES];
    }
}

-(IBAction)printbtn:(id)sender
{
    //利用 NSLog 來查看剛才取得的 plist 檔的內容
    NSLog(@"Location.plist:%@",equpmentDictionary);
}

-(IBAction)resetbtn:(id)sender
{
    equpmentDictionary = [[NSMutableDictionary alloc] init];
    NSLog(@"Create a new 'Loaction.plist' file.");
    [equpmentDictionary setObject:@"0" forKey:@"length"];
    [self storeLoctionPlist];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
