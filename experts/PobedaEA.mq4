//
// �������� �� ��������� "������ ������ 1" � ������ tradelikeapro.ru �� Skylover410
//
#property copyright "EURUSD-M1 (c) dev by Graybit"
#property link      "konstantin.kuklin@gmail.com"

//////////////// INCLUDE
//#include <stdlib.mqh>

//////////////// DEFINE CONFIG
#define TREND_METHOD_MA           1
#define TREND_METHOD_ULTRA_SIGNAL 2
#define TREND_METHOD_TMA_SLOPE    3

#define UP     1
#define MIDDLE 0
#define DOWN   -1

//////////////// EXTERNAL VARIABLES
extern bool   extUseMM        = false;
extern int    extRiskPercent  = 3;
extern double extFixLotSize   = 0.01;
extern bool   isTest          = true;
extern bool   extShowComment  = false;
extern bool   extDoScreenShot = true;
//////////
extern bool ProfitTrailing = TRUE;
extern double TrailingStop = 15.0;
extern double TrailingStep = 2.0;
extern int MagicNumber = 4371; // TODO REFACTOR
//////////
extern int EA_magic = 4371;

extern bool tradeOnlyInTime = false;   
extern int  gmtshift        = -1;                   // gmt offset
extern int  StartHour       = 7;
extern int  StartMinute     = 0;
extern int  EndHour         = 21;
extern int  EndMinute       = 0;

extern string  Comment_NewsFilter = "������ �������� �� ����� ��������";
extern bool    UseNewsFilter      = false;
extern int     MinsBeforeNews     = 10; // mins before an event to stay out of trading
extern int     MinsAfterNews      = 20; // mins after  an event to stay out of trading
extern bool 	IncludeHigh 		 = true;
extern bool 	IncludeMedium 		 = true;
extern bool 	IncludeLow 			 = false;
extern bool 	IncludeSpeaks 		 = true; 		// news items with "Speaks" in them have different characteristics

//////////////// VARIABLES

bool NewsTime          = false,
     IncludeOpenEquity = true
;

int minutesUntilNextEvent = 0,
    minutesSincePrevEvent = 0,

    profitPips            = 50,
    stopLossPips          = 150,
    myOrdersList[],
    tmaM1VectorSmall,tmaM1VectorBig,
    newsLastMinuteCheck   = -1,
    screenShotLastMinuteCheck = -1
;

// start variables for calculateNewVariables()
double valSSRC[5],
       spreadSize,
       
       tmaM1Size, tmaTrand, tmaM1Up[5],tmaM5Size,
       tmaM1Down[5],
       tmaM1Middle,tmaM1Middle10,tmaM1Middle70,
       tmaM5Middle,tmaM5Middle4,
       tmaM5Up[5],tmaM5Down[5],
       kanal,
       USDPower, EURPower
;
double gd_100; // for trailing

string TrendInfo;
// end variables for calculateNewVariables()

bool  buyVector,
      buyTouch,
      buySSRC,
      buyTmaSize,
      buyPower,
      buyM5,
      buyNeedPips,
      
      sellVector,
      sellTouch,
      sellSSRC,
      sellTmaSize,
      sellPower,
      sellM5,
      sellNeedPips
;     

bool stopLossModify2 = false,
     stopLossModify10 = false,
     stopLossModify25 = false;
     
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() { 
   gd_100 = Point;
   if (Digits == 5 || Digits == 3) {
      gd_100 = 10.0 * gd_100;
   }
   
   spreadSize = MathAbs(Bid-Ask) / Point;
   return(0); 
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() { return(0); }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+

bool globalTrade = false;
int start()
{
   double lotSize;
   

   RefreshRates();
   getMyOrders(myOrdersList);
   
   calculateNewVariables();
   // ���� � ��� ���� �������� �������
   if(ArraySize(myOrdersList) > 0){
      //Print("Orders");
      //checkToClose();
      modifyStopLoss();
   }else{
      
      stopLossModify2 = false;
      stopLossModify10 = false;
      stopLossModify25 = false;
     
      // ���� ������� �������� ���
      lotSize = calculateLotSize();
      if(lotSize == 0){
         Print("No money");
         return(0);
      }
      
      globalTrade = false;
      // ���������� ������� ��� ��������
      if(isTradeTime() && isNoNews()){
         
         globalTrade = true;
         //Print("Yes");
         if(isGoodPositionToBuy()){
            // ������ � �������
            openBuyOrder(lotSize);
            //Print("Buy");
         }else if(isGoodPositionToSell()){
            // ������ � �������
            openSellOrder(lotSize);
            //Print("Sell");
         }  
      }
   }
      
   

   if(extShowComment) {
      Comment(" \nPobeda v1.09", 
         "\n��������� �����" + TimeToStr(TimeCurrent(), TIME_SECONDS) + " (GMT: "+TimeToStr(TimeCurrent()-gmtshift*3600, TIME_SECONDS)+")", 
         "\n�������� �����: " + boolToStr(isTradeTime()),
         "\n�������� ������: "+boolToStr(ArraySize(myOrdersList)),
         "\n���� � ��������: "+boolToStr(globalTrade),
         "\n������ ����: "+DoubleToStr(calculateLotSize(),2),
            
         "\n\n������ �� �������: "+boolToStr(buyVector),
         "\n������� ������� ������: "+boolToStr(buyTouch),
         "\nSSRC �� �������: "+boolToStr(buySSRC),
         "\nTMA ������: "+boolToStr(buyTmaSize),
         "\n���� ������� �������: "+boolToStr(buyPower),
         "\n�� �5 ���� ���� ��������: "+boolToStr(buyM5),
         "\n�� �������� ������ ������ ����������: "+boolToStr(buyNeedPips),
      
         "\n\n������ �� �������: "+boolToStr(sellVector),
         "\n������� �������� ������: "+boolToStr(sellTouch),
         "\nSSRC �� �������: "+boolToStr(sellSSRC),
         "\nTMA ������: "+boolToStr(sellTmaSize),
         "\n���� ������ �������: "+boolToStr(sellPower),
         "\n�� �5 ���� ���� ��������: "+boolToStr(sellM5),
         "\n�� ������� ������ ������ ����������: "+boolToStr(sellNeedPips),
      
         "\n");
   }
   
   // ����������� ��
   if(extDoScreenShot){
      makeScreenShot();
   }
   
   //iCustom(NULL, 0, "Screnshoter", 0, 0);
   return(0);
}
//+------------------------------------------------------------------+

// ���������, ����� �� ��������� ��� �������� ������
void checkToClose(){

}
     
void modifyStopLoss(){
   OrderSelect(0, SELECT_BY_POS, MODE_TRADES);
   
   // �������� ��������, ���� ��� ��������� 25 ���� ����
   if(stopLossModify25){
      Print("Trail");
      realTrailOrder();
   }else{
      Print((OrderOpenPrice() - Close[0]) / Point);
      // ���� ������ �� �������
      if(OrderType()==OP_SELL){
         if(!stopLossModify2 && (OrderOpenPrice() - Close[0]) / Point > 20) { // ���� ������ ������ 10
            OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() - (5 * Point) ,OrderTakeProfit(),0,Green);
            stopLossModify2 = true;   
         }else if(!stopLossModify10 && (OrderOpenPrice() - Close[0]) / Point > 25) { // ���� ������ ������ 10
            OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() - (10 * Point) ,OrderTakeProfit(),0,Green);
            stopLossModify25 = true;   
         }else if(!stopLossModify25 && (OrderOpenPrice() - Close[0]) / Point > 40) { // ���� ������ ������ 35
            OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() - (25 * Point) ,OrderTakeProfit(),0,Green);
            stopLossModify25 = true;
         }
      }else{
         // ���� ������ �� �������
         if(!stopLossModify2 && (Close[0] - OrderOpenPrice()) / Point > 20) { // ���� ������ ������ 10
            OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() + (5 * Point) ,OrderTakeProfit(),0,Green);
            stopLossModify2 = true;   
         }else if(!stopLossModify10 && (Close[0] - OrderOpenPrice()) / Point > 25) { // ���� ������ ������ 10
            OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() + (10 * Point) ,OrderTakeProfit(),0,Green);
            stopLossModify25 = true;   
         }else if(!stopLossModify25 && (Close[0] - OrderOpenPrice()) / Point > 40) { // ���� ������ ������ 35
            OrderModify(OrderTicket(),OrderOpenPrice(),OrderOpenPrice() + (25 * Point) ,OrderTakeProfit(),0,Green);
            stopLossModify25 = true;
         }
      }
   }
}


bool isGoodPositionToBuy(){
   buyVector = true;
   buyTouch = true;
   buySSRC = true;
   buyTmaSize = true;
   buyPower = true;
   buyM5 = true;
   buyNeedPips = true;

   bool trade = true;
   //���� �� �������:
   if(tmaM1VectorSmall == tmaM1VectorBig){
      // ����� ������
   }
   
   //1) ��� �� �1 ��������� �����, ���� ������������
   if(tmaM1VectorSmall == DOWN || tmaM1VectorSmall != tmaM1VectorBig){ // �� ����� ����� ������ �� �������
      trade = false;
      buyVector = false;
   }
   //2) ���� ��������� ������ ����� ��� � ������ ���������������
   bool touch = false;
   for(int i=0; i < 4; i++){
      if(Low[i] - (3 * Point) <= tmaM1Down[i]){ // 3 ������ ������� ���� �� �������
         touch = true;
         //Print(Low[i] + "-" + (3 * Point) +"-"+ tmaM1Down[i]);
      }
   }
   if(!touch){
      trade = false;
      buyTouch = false;
   }
   
   //
   if(!(valSSRC[3] <= -0.9 && valSSRC[2] <= -0.9 && valSSRC[0] > -0.8) //3) SSRC � ��������� ��������� �����
   //   && !((valSSRC[0] <= -0.9 && valSSRC[1] <= -0.9) && (Close[0] - (10 * Point) < tmaM1Down[0])) // ������������� �����, ���� ��������� ������ ���� ������ ��� ����
   ){
      trade = false;
      buySSRC = false;
   }

   //4) ������ ��A ������ ��� ����� 10 �������
   if(tmaM1Size < 100 &&
      (tmaM1Up[0] - Close[0]) / Point < 100 // ���� ���� �������� �� ���� ����� �����������
      //(tmaM1Up[0] - Close[0]) / Point < 100 + (spreadSize / 2) // ���� ���� �������� �� ���� ����� �����������
   ) {
      trade = false;
      buyTmaSize = false;
   }
   //5) Currency Power Meter: ���� ���� ������ ��� ����� ���� �������.
   if(EURPower < USDPower && !isTest){
      trade = false;
      buyPower = false;
   }
   //6) ��=15, ��=5
   // ������!
   
   //7) �� �5 ���� ��������� � ������ ����� ������ ���, ���� �� ��������. �� ����� �� ����� ������� ����� TMA.
   if(Close[0] > tmaM5Middle && !isTest){
      trade = false;
      buyM5 = false; 
   }
   
   //8) �� ��������������� ������� ������ ��� ��������� ������ � ������� ������
   if(tmaM1Up[0] - Close[0] < (spreadSize + profitPips) * Point){
      trade = false;
      buyNeedPips = false;
   }
   
   return(trade);
}

// ��������� ����� �� ����� � ������
bool isGoodPositionToSell(){

   sellVector = true;
   sellTouch = true;
   sellSSRC = true;
   sellTmaSize = true;
   sellPower = true;
   sellM5 = true;
   sellNeedPips = true;

   bool trade = true;
   //���� �� �������:
   //1) ��� �� �1 ��������� ����, ���� ������������
   if(tmaM1VectorSmall == UP || tmaM1VectorSmall != tmaM1VectorBig){
      trade = false;
      sellVector = false;
   }

   //2) ���� ��������� ������� ����� ��� � ������ ���������������
   bool touch = false;
   for(int i=0; i < 4; i++){
      if(High[i] + (3 * Point) >= tmaM1Up[i]){ // 3 ������ ��� ������� ��������
         touch = true;
         //Print(High[i] + "-" + (3 * Point) +"-"+ tmaM1Up[i]);
      }
   }
   if(!touch){
      trade = false;
      sellTouch = false;
   }
   
   //
   if(!(valSSRC[3] > 0.9 && valSSRC[2] > 0.9 && valSSRC[0] < 0.8) //3) SSRC � ��������� ��������� ����
   //   && !((valSSRC[0] >= 0.9 && valSSRC[1] >= 0.9) && (Close[0] - (10 * Point) > tmaM1Up[0])) // ������������� �����, ���� ��������� ������ ���� ������ ���
   ){
      trade = false;
      sellSSRC = false;
   }
   
   //4) ������ ��A ������ ��� ����� 10 �������
   if(tmaM1Size < 100 &&
     (Close[0] - tmaM1Down[0]) / Point < 100 // ���� ���� �������� �� ���� ����� �����������
     //(Close[0] - tmaM1Down[0]) / Point < 100 + (spreadSize / 2) // ���� ���� �������� �� ���� ����� �����������
   ) {
      trade = false;
      sellTmaSize = false;
   }
   //5) Currency Power Meter: ���� ���� ������ ��� ����� ���� �������.
   if(EURPower > USDPower && !isTest){
      trade = false;
      sellPower = false;
   }
   //6) ��=15, ��=5
   // ������!
   
   //7) �� �5 ���� ��������� � ������� ����� ������ ���, ���� �� ��������. �� ����� �� ����� ������ ����� TMA.
   if(Close[0] < tmaM5Middle){
      trade = false;
      sellM5 = false;
   }
   
   //8) �� ��������������� ������� ������ ��� ��������� ������ � ������� ������
   if(Close[0]-tmaM1Down[0] < (spreadSize + profitPips) * Point){
      trade = false;
      sellNeedPips = false;
   }
   
   return(trade);
}

// ��������� ������ �� �������
void openBuyOrder(double lotSize){
   double stop = NormalizeDouble(Ask - (stopLossPips * Point),Digits);
   //double take = NormalizeDouble(Ask + (profitPips * Point),Digits);
   OrderSend(Symbol(),OP_BUY, lotSize, Ask, 10, stop, 0, "", EA_magic, 0, 0);
}

// ��������� ������ �� �������
void openSellOrder(double lotSize){
   double stop = NormalizeDouble(Bid + (stopLossPips * Point),Digits);
   //double take = NormalizeDouble(Bid - (profitPips * Point),Digits);
   OrderSend(Symbol(),OP_SELL, lotSize, Bid, 10, stop, 0, "", EA_magic, 0, 0);
}

// �������� ����� �������� ��� ����������
void calculateNewVariables(){

   for(int i=0;i < 6;i++){
      tmaM1Up[i] = iCustom(NULL,PERIOD_M1,"TMA with Distances",
                     "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 1,i);
      tmaM1Down[i] = iCustom(NULL,PERIOD_M1,"TMA with Distances",
                     "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 2,i); 
      tmaM5Up[i] = iCustom(NULL,PERIOD_M5,"TMA with Distances", 
                     "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 1,i);
      tmaM5Down[i] = iCustom(NULL,PERIOD_M5,"TMA with Distances", 
                     "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 2,i);
      
      valSSRC[i]=iCustom(NULL, 0, "SSRC", 3, 21, 2, 6, 0,i);  
   }

   tmaM1Middle   = iCustom(NULL,PERIOD_M1,"TMA with Distances", 
                    "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,0);
   tmaM1Middle10 = iCustom(NULL,PERIOD_M1,"TMA with Distances", 
                    "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,10);                                   
   tmaM1Middle70 = iCustom(NULL,PERIOD_M1,"TMA with Distances", 
                    "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,70);
/*
   tmaM5Middle = iCustom(NULL,PERIOD_M5,"TMA with Distances", 
                  "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,0);
   tmaM5Middle70 = iCustom(NULL,PERIOD_M5,"TMA with Distances", 
                  "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,4);
*/
   tmaM1Size = (tmaM1Up[0] - tmaM1Down[0]) / Point;
   tmaM5Size = (tmaM5Up[0] - tmaM5Down[0]) / Point;
   
   if(tmaM1Middle10 == tmaM1Middle){
      tmaM1VectorSmall = MIDDLE;
   }
   
   if(tmaM1Middle > tmaM1Middle10){
      tmaM1VectorSmall = UP;
   }else{
      tmaM1VectorSmall = DOWN;
   }

   if(tmaM1Middle70 == tmaM1Middle){
      tmaM1VectorBig = MIDDLE;
   }
   
   if(tmaM1Middle > tmaM1Middle70){
      tmaM1VectorBig = UP;
   }else{
      tmaM1VectorBig = DOWN;
   }
   
   EURPower = iCustom(NULL,PERIOD_M1,"CurrencyPowerMeter_fixed_Graybit", 0,0);
   USDPower = iCustom(NULL,PERIOD_M1,"CurrencyPowerMeter_fixed_Graybit", 1,0);
   
} // end calculateNewVariables()

// ������ ������ ������
double calculateLotSize(){   
   double balance, riskBalance, lot;
   
   // ���� �� ������� ����� ������� ������, �� ����� ������������� ��������
   if(!extUseMM){
      return(extFixLotSize);
   }
   
   balance = AccountBalance();
   // ��� ������� ������� ���������� 0
   if(balance == 0){
      return(0);
   }
   
   // ���-�� �����, ������� �� ������ ����������
   riskBalance = balance * extRiskPercent / 100.0;
   lot = riskBalance / stopLossPips;
   if(lot < 0.01) {
      lot = 0.01;
   }

   // ������ ������, ����� ���������� ���� ����� ��� ����
   return(lot);
}

// ���������� ������ �������� ������
int getMyOrders(int& variableList[]){
   int totalOrders = OrdersTotal();
   ArrayResize(variableList, totalOrders);
   
   int a=0;
   for( int i = 0 ; i < totalOrders ; i++ ){
      if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ){
         break;
      }
        
      if( OrderMagicNumber() != EA_magic ){
         continue;
      }
      
      if( OrderSymbol() != Symbol() ){
         continue;
      }
      variableList[a] = i;
      a++;
   }
   
   return(variableList);
}

// ��������� ��������� ���� ������������� �� ������ 
bool isTradeTime() {
   // ���� ����� ��������� � ����� �����
   if(!tradeOnlyInTime){
      return(true);
   }
   
   int now = 60 * TimeHour(TimeCurrent()) + TimeMinute(TimeCurrent());
   int start = 60 * (StartHour+gmtshift) + StartMinute;
   int end = 60 * (EndHour+gmtshift) + EndMinute;
   
   if (start == end) {
      return (false);
   }else if (start < end) {
      if (!(!(now >= start && now < end))){ 
         return (true);
      }
      return (false);
   }else if (start > end) {
      if (!(!(now >= start || now < end))){ 
         return (true);
      }
      return (false);
   }
   
   return (false);
}

// ������������ int � ��\���
string boolToStr (int value) 
{
   if(value > 0){
      return ("��");
   }
   
   return ("���");
}

// ���������, �������� �� �������� � ��� �� ������� � ��������� �����
bool isNoNews()
{
   if(isTest){
      return(true);
   }
   
   // ���� ������� ������ �� ���������� - ������
   if (Minute() != newsLastMinuteCheck)
   {
      newsLastMinuteCheck = Minute();
      minutesSincePrevEvent =
         iCustom(NULL, 0, "FFCal-fix_by_stelz", IncludeHigh, IncludeMedium, IncludeLow, IncludeSpeaks, true, gmtshift, 1, 0);

      minutesUntilNextEvent =
         iCustom(NULL, 0, "FFCal-fix_by_stelz", IncludeHigh, IncludeMedium, IncludeLow, IncludeSpeaks, true, gmtshift, 1, 1);

      NewsTime = true;
      // ���������, ���� ����� �� ������� ������ ��� ������, ��� �������, �� �������� ��������
      if (
         minutesUntilNextEvent <= MinsBeforeNews || 
         minutesSincePrevEvent <= MinsAfterNews
      ) {
          NewsTime = false;
      }
   }
   
   return(NewsTime);
}// end checkNews()

// strailing stop function
void realTrailOrder() {
   double l_ord_open_price_20;
   double l_ord_stoploss_28;
   double l_price_36;
   double ld_0 = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point / gd_100;
   double ld_8 = MathMax(TrailingStop, ld_0);
   
   for (int l_pos_16 = OrdersTotal() - 1; l_pos_16 >= 0; l_pos_16--) {
      if (OrderSelect(l_pos_16, SELECT_BY_POS, MODE_TRADES) == TRUE) {
         if (OrderMagicNumber() == MagicNumber || MagicNumber < 0 && OrderSymbol() == Symbol()) {
            l_ord_open_price_20 = OrderOpenPrice();
            l_ord_stoploss_28 = OrderStopLoss();
            while (IsTradeContextBusy()) {
               Sleep(500);
            }
            RefreshRates();
            if (OrderType() == OP_BUY) {
               l_price_36 = getNormalizeDouble(Bid - ld_8 * gd_100);
               
               // ���� ������� ���� �������� ������, ��� ���� �������� ������ + ������ ���������(15) 
               if ((Bid > l_ord_open_price_20 + ld_8 * gd_100 || !ProfitTrailing) 
                  && l_price_36 >= l_ord_stoploss_28 + TrailingStep * gd_100 
                  && ld_8 * gd_100 > ld_0 * gd_100
                  ) {
                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), l_price_36, 0, 0, Blue)){
                     if (!IsOptimization()) {
                        Print("BUY OrderModify Error " + GetLastError());
                     }
                  }
               }
            }
            if (OrderType() == OP_SELL) {
               l_price_36 = getNormalizeDouble(Ask + ld_8 * gd_100);
               if ((Ask < l_ord_open_price_20 - ld_8 * gd_100 || !ProfitTrailing) 
                  && l_price_36 <= l_ord_stoploss_28 - TrailingStep * gd_100 
                  && ld_8 * gd_100 > ld_0 * gd_100
                  ) {
                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), l_price_36, 0, 0, Red)){
                     if (!IsOptimization()) {
                        Print("Sell OrderModify Error " + GetLastError());
                     }
                  }
               }
            }
         }
      }
   }
}

double getNormalizeDouble(double ad_0) {
   return (NormalizeDouble(ad_0, Digits));
}

void makeScreenShot(){
   WindowRedraw();
   Sleep(5000);
   // ���� ������� ������ �� ���������� - ������
   if (Minute() != screenShotLastMinuteCheck && Minute()-1 != screenShotLastMinuteCheck)
   {
      screenShotLastMinuteCheck = Minute();
      string ScreenShotFileName = Symbol()+"_"+TimeToStr(TimeCurrent(),TIME_DATE)+"_"+Hour()+"."+Minute()+".gif";   
      Print(ScreenShotFileName);
      WindowScreenShot(ScreenShotFileName,800,600);      
   }
}