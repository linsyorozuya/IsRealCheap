//
//  TodayViewController.m
//  IsRealCheapWidget
//
//  Created by Lin on 2015/1/3.
//  Copyright © 2017年 Lin. All rights reserved.
//

#import "TodayViewController.h"
#import <NotificationCenter/NotificationCenter.h>
#import "TextViewController.h"

@interface TodayViewController () <NCWidgetProviding>

@property (nonatomic,strong) NSArray *historyPriceArray;
@property (nonatomic,strong) NSMutableArray *dateArray;
@property (nonatomic,strong) NSMutableArray *priceArray;

@property (weak, nonatomic) IBOutlet UILabel *lowestPriceLabel;
@property (weak, nonatomic) IBOutlet UILabel *lowestPriceDateLabel;
@property (weak, nonatomic) IBOutlet UILabel *productNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *commonPriceLabel;
@property (weak, nonatomic) IBOutlet UILabel *hightestPriceLabel;
@property (weak, nonatomic) IBOutlet UILabel *hightestPriceDateLabel;

@property (weak, nonatomic) IBOutlet UIView *contentContainerView;

@property (nonatomic,strong) NSUserDefaults *userDefault;
@end

@implementation TodayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    /** 获取上一次查询的记录 */
    _userDefault = [[NSUserDefaults alloc] initWithSuiteName:@"group.com.isRealCheap"];
    
    /** 设置 widget 展示样式可折叠 */
    self.extensionContext.widgetLargestAvailableDisplayMode = NCWidgetDisplayModeCompact;
    
    /** 获取剪贴板内容 */
    [self getClipBoardContent];
}

#pragma mark - 获取剪贴板内容
- (void)getClipBoardContent
{
    //识别剪贴板中的内容
    NSString *paste = UIPasteboard.generalPasteboard.string;
    NSString *lastProductUrl = [_userDefault valueForKey:@"lastProductUrl"];
    if(([paste containsString:@"http://"]||[paste containsString:@"https://"])&&![lastProductUrl isEqualToString:paste] )
    {
        /** 乱七八糟的淘宝地址,截取出链接地址 */
        NSArray *separateUrlArray = [paste componentsSeparatedByString:@"http"];
        if (separateUrlArray.count>1) {
            NSArray *separateArray = [separateUrlArray[1] componentsSeparatedByString:@"，"];

            paste = [@"http" stringByAppendingString:separateArray[0]];
            paste = [paste stringByReplacingOccurrencesOfString:@" " withString:@""];
        }
        
        _lowestPriceLabel.text = @"🔍";
        _commonPriceLabel.text = @"🔍";
        _hightestPriceLabel.text = @"🔍";
        
        /** 获取历史价格 */
        [self requestHistoryPrice:paste];
        
        /** 保存最近一次查询的商品链接 */
        [_userDefault setObject:paste forKey:@"lastProductUrl"];
        [_userDefault synchronize];
    }
    else
    {
        _lowestPriceLabel.text = [_userDefault valueForKey:@"lastProductLowestPrice"] ? : @"🔍";
        _lowestPriceDateLabel.text = [_userDefault valueForKey:@"lastProductLowestPriceDate"] ? :@"🔍🔍🔍🔍" ;

        _productNameLabel.text = [_userDefault objectForKey:@"lastProductName"] ? :@"🔍🔍🔍🔍🔍🔍";
        _commonPriceLabel.text = [_userDefault valueForKey:@"lastProductCommonPrice"] ? : @"🔍";
        
        _hightestPriceLabel.text = [_userDefault valueForKey:@"lastProductHightestPrice"] ? : @"🔍";
        _hightestPriceDateLabel.text = [_userDefault valueForKey:@"lastProductHightestPriceDate"] ? :@"🔍🔍🔍🔍" ;
    }
}

#pragma mark - 获取商品的历史价格
- (void)requestHistoryPrice:(NSString *)productUrl
{
    productUrl = [productUrl componentsSeparatedByString:@"，"][0];
    //1.确定请求路径
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://tool.manmanbuy.com/m/history.aspx?DA=1&action=gethistory&url=%@",productUrl]];
    
    //2.创建请求对象
    //请求对象内部默认已经包含了请求头和请求方法（GET）
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    //3.获得会话对象
    NSURLSession *session = [NSURLSession sharedSession];
    
    //4.根据会话对象创建一个Task(发送请求）
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error == nil) {
            //6.解析服务器返回的数据
            //说明：（此处返回的数据是JSON格式的，因此使用NSJSONSerialization进行反序列化处理）
            NSData *encodeData = [self gb2312toutf8:data];
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:encodeData options:NSJSONReadingMutableLeaves error:nil];
            
            NSString *priceData = dict[@"jsData"];
            
            priceData = [priceData stringByReplacingOccurrencesOfString:@"],[" withString:@"$"];
            priceData = [priceData stringByReplacingOccurrencesOfString:@"]" withString:@""];
            priceData = [priceData stringByReplacingOccurrencesOfString:@"[" withString:@""];
            priceData = [priceData stringByReplacingOccurrencesOfString:@"Date.UTC(" withString:@""];
            priceData = [priceData stringByReplacingOccurrencesOfString:@")," withString:@"#"];

            _historyPriceArray = [priceData componentsSeparatedByString:@"$"];
            [self filterHistoryPriceArray];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                _lowestPriceLabel.text = [NSString stringWithFormat:@"%@",@([dict[@"zdprice"] integerValue]).stringValue];
                _lowestPriceDateLabel.text = [NSString stringWithFormat:@"%@",dict[@"zdtime"]] ? : @"🔍🔍🔍🔍";
                _productNameLabel.text = dict[@"spname"] ? : @"🔍🔍🔍🔍🔍🔍";
                _commonPriceLabel.text = [self caculateCommomPrice] ? : @"🔍";
                _hightestPriceLabel.text = [self caculateHightestPrice] ? : @"🔍";
                _hightestPriceDateLabel.text = [self caculateHightestPriceDate] ? : @"🔍🔍🔍🔍";

                _lowestPriceLabel.text = (![_lowestPriceLabel.text isEqualToString:@""])? _lowestPriceLabel.text : @"🔍";
                _lowestPriceDateLabel.text = (![_lowestPriceDateLabel.text isEqualToString:@""])? _lowestPriceDateLabel.text : @"🔍🔍🔍🔍";
                _productNameLabel.text = (![_productNameLabel.text isEqualToString:@""])? _productNameLabel.text : @"🔍🔍🔍🔍🔍🔍";
                _commonPriceLabel.text = (![_commonPriceLabel.text isEqualToString:@""])? _commonPriceLabel.text : @"🔍";
                _hightestPriceLabel.text = (![_hightestPriceLabel.text isEqualToString:@""])? _hightestPriceLabel.text : @"🔍";
                _hightestPriceDateLabel.text = (![_hightestPriceDateLabel.text isEqualToString:@""])? _hightestPriceDateLabel.text : @"🔍🔍🔍🔍";

                /** 最近一次查询的商品链接 */
                [_userDefault setObject:_lowestPriceLabel.text forKey:@"lastProductLowestPrice"];
                [_userDefault setObject:_lowestPriceDateLabel.text forKey:@"lastProductLowestPriceDate"];
                [_userDefault setObject:_productNameLabel.text forKey:@"lastProductName"];
                [_userDefault setObject:_commonPriceLabel.text forKey:@"lastProductCommonPrice"];
                [_userDefault setObject:_hightestPriceLabel.text forKey:@"lastProductHightestPrice"];
                [_userDefault setObject:_hightestPriceDateLabel.text forKey:@"lastProductHightestPriceDate"];

                [_userDefault synchronize];
            });
        }
        else
        {
            NSLog(@"error===%@",error);
        }
    }];
    
    //5.执行任务
    [dataTask resume];
    
}

/** NSData 编码转换 */
-(NSData *)gb2312toutf8:(NSData *) data
{
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
    NSString *retStr = [[NSString alloc] initWithData:data encoding:enc];
    NSData* encodeData = [retStr dataUsingEncoding:NSUTF8StringEncoding];
    return encodeData;
}


#pragma mark - 切换展开和折叠的模式
- (void)widgetActiveDisplayModeDidChange:(NCWidgetDisplayMode)activeDisplayMode withMaximumSize:(CGSize)maxSize
{
    if (activeDisplayMode == NCWidgetDisplayModeCompact) {
        self.preferredContentSize = maxSize;
    }else
    {
        self.preferredContentSize = CGSizeMake(maxSize.width, 300);
    }
}

#pragma mark - 数据解析
- (void)filterHistoryPriceArray
{
    _dateArray = [NSMutableArray new];
    _priceArray = [NSMutableArray new];
    [_historyPriceArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *historyStr = _historyPriceArray[idx];
        NSArray *historyStrArray = [historyStr componentsSeparatedByString:@"#"];
        
        NSString *dateStr = historyStrArray[0];
        NSInteger price = [historyStrArray[1] intValue];
        
        NSArray *separateDateArray = [dateStr componentsSeparatedByString:@","];
        NSString *date = [NSString stringWithFormat:@"%@/%@/%@",separateDateArray[0],separateDateArray[1],separateDateArray[2]];
        
        [_dateArray addObject:date];
        [_priceArray addObject:@(price)];
        
    }];
}

/** 计算平常价格 */
- (NSString *)caculateCommomPrice
{
    int counts ;
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSMutableArray *countsArray = [NSMutableArray new];
    for (int q = 0; q < _priceArray.count; q++) {
        counts = 0;
        for (int l = 0; l < _priceArray.count; l++) {
            if([_priceArray objectAtIndex:q] == [_priceArray objectAtIndex:l]) {
                counts += 1;
            }
        }
        [dict setObject:[NSNumber numberWithInt:counts] forKey:[_priceArray objectAtIndex:q]];
        [countsArray addObject:[NSNumber numberWithInt:counts]];
    }
    int countMax = [[countsArray valueForKeyPath:@"@max.intValue"] intValue];
    NSInteger index = [countsArray indexOfObject:[NSNumber numberWithInteger:countMax]];
    return @([_priceArray[index] intValue]).stringValue;
}

/** 计算最高价格 */
- (NSString *)caculateHightestPrice
{
    NSInteger maxPrice = [[_priceArray valueForKeyPath:@"@max.intValue"] intValue];
    NSInteger index = [_priceArray indexOfObject:[NSNumber numberWithInteger:maxPrice]];
    return @([_priceArray[index] integerValue]).stringValue;
}

/** 计算最高价格日期 */
- (NSString *)caculateHightestPriceDate
{
    NSArray* reversePriceArray = [[_priceArray reverseObjectEnumerator] allObjects];
    NSArray* reverseDateArray = [[_dateArray reverseObjectEnumerator] allObjects];
    NSInteger maxPrice = [[reversePriceArray valueForKeyPath:@"@max.intValue"] intValue];
    NSInteger index = [reversePriceArray indexOfObject:[NSNumber numberWithInteger:maxPrice]];
    return reverseDateArray[index];
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    // Perform any setup necessary in order to update the view.
    
    // If an error is encountered, use NCUpdateResultFailed
    // If there's no update required, use NCUpdateResultNoData
    // If there's an update, use NCUpdateResultNewData

    completionHandler(NCUpdateResultNewData);
}

@end
