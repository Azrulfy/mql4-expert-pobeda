//
// �������� �� ��������� "������ ������ 1" � ������ tradelikeapro.ru �� Skylover410
//
#property copyright "EURUSD-M1 (c) dev by Graybit"
#property link      "konstantin.kuklin@gmail.com"

//////////////// INCLUDE
#include <stdlib.mqh>

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
int   profitPips = 50;
int   stopLossPips = 150;
extern int sleepTimeMS   = 200;
extern bool isTest = true;


int myOrdersList[];
//////////
extern int EA_magic = 4371;

extern bool tradeOnlyInTime = false;   
extern int  gmtshift        = 3;                   // gmt offset
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

bool NewsTime = false;
int minutesUntilNextEvent = 0;
int minutesSincePrevEvent = 0;

///
/////////////////////////////////////////////////////////////
// news check
int newsLastMinuteCheck = -1;
////////////////////////////////////////////////////////////
extern bool IncludeOpenEquity = TRUE;
//////


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init() { return(0); }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit() { return(0); }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+

// start variables for calculateNewVariables()
int tmaM1Vector;
double valSSRC[5],spreadSize,
       
       tmaM1Size, tmaTrand, tmaM1Up[5],tmaM5Size,
       tmaM1Down[5],
       tmaM1Middle,tmaM1Middle4,
       tmaM5Middle,tmaM5Middle4,
       tmaM5Up[5],tmaM5Down[5],
       kanal,
       USDPower, EURPower
;
string TrendInfo;
// end variables for calculateNewVariables()

int start()
{
   double lotSize;
   

   RefreshRates();
   getMyOrders(myOrdersList);
   
   calculateNewVariables();
   // ���� � ��� ���� �������� �������
   if(ArraySize(myOrdersList) > 0){
      checkToClose();
   }else{
      // ���� ������� �������� ���
      lotSize = calculateLotSize();
      if(lotSize == 0){
         Print("No money");
         return(0);
      }
      
      // ���������� ������� ��� ��������
      if(isTradeTime() && !isNewsComming()){
         if(isGoodPositionToBuy()){
            // ������ � �������
            //openBuyOrder(lotSize);
            Print("Buy");
         }else if(isGoodPositionToSell()){
            // ������ � �������
            //openSellOrder(lotSize);
            Print("Sell");
         }  
      }
   }
      
   


   Comment(" \nPobeda v1.09", 
      "\n��������� �����" + TimeToStr(TimeCurrent(), TIME_SECONDS) + " (GMT: "+TimeToStr(TimeCurrent()-gmtshift*3600, TIME_SECONDS)+")", 
      "\n�������� ������: "+boolToStr(ArraySize(myOrdersList)),
      "\n�����: "+DoubleToStr(spreadSize/Point, 1),
      "\n������ ������ tmaM1Size: "+DoubleToStr(tmaM1Size,1),
      "\nTMA Sell: "+boolToStr(isGoodPositionToSell()),
      "\nTMA Buy: "+boolToStr(isGoodPositionToBuy()),
      "\n������ �� ��������: "+boolToStr(isNewsComming()),
      "\n tmaM1Vector: "+tmaM1Vector,
      "\n tmaM1Up[0]: "+tmaM1Up[0],
      "\n tmaM1Middle: "+tmaM1Middle,
      "\n tmaM1Down[0]: "+tmaM1Down[0],
      "\n EURPower: "+DoubleToStr(EURPower,1),
      "\n USDPower: "+DoubleToStr(USDPower,1),
      "\n lotSize: "+DoubleToStr(calculateLotSize(),2),
      
      
   "\n");
   
   return(0);
}
//+------------------------------------------------------------------+

// ���������, ����� �� ��������� ��� �������� ������
void checkToClose(){

}

bool isGoodPositionToBuy(){
   bool trade = true;
   //���� �� �������:

   //1) ��� �� �1 ��������� �����, ���� ������������
   if(tmaM1Vector == DOWN){
      trade = false;
   }
   //2) ���� ��������� ������ ����� ��� � ������ ���������������
   bool touch = false;
   for(int i=0; i < 5; i++){
      if(Low[i] <= tmaM1Down[i]){
         touch = true;
      }
   }
   if(!touch){
      trade = false;
   }
   //3) SSRC � ��������� ��������� �����
   if(!(valSSRC[3] > 0.9 && valSSRC[2] > 0.9 && valSSRC[0] < 0.8)){
      trade = false;
   }
   //4) ������ ��A ������ ��� ����� 10 �������
   if(tmaM1Size < 100) {
      trade = false;
   }
   //5) Currency Power Meter: ���� ���� ������ ��� ����� ���� �������.
   if(EURPower < USDPower){
      trade = false;
   }
   //6) ��=15, ��=5
   // ������!
   
   //7) �� �5 ���� ��������� � ������ ����� ������ ���, ���� �� ��������. �� ����� �� ����� ������� ����� TMA.
   if(Close[0] > tmaM5Middle && !isTest){
      trade = false; 
   }
}

// ��������� ����� �� ����� � ������
bool isGoodPositionToSell(){
   bool trade = true;
   //���� �� �������:
   //1) ��� �� �1 ��������� ����, ���� ������������
   if(tmaM1Vector == UP){
      trade = false;
   }

   //2) ���� ��������� ������� ����� ��� � ������ ���������������
   bool touch = false;
   for(int i=0; i < 5; i++){
      if(High[i] >= tmaM1Up[i]){
         touch = true;
      }
   }
   if(!touch){
      trade = false;
   }
   //3) SSRC � ��������� ��������� ����
   if(!(valSSRC[3] < -0.9 && valSSRC[2] < -0.9 && valSSRC[0] > -0.8)){
      trade = false;
   }
   
   //4) ������ ��A ������ ��� ����� 10 �������
   if(tmaM1Size < 100) {
      trade = false;
   }
   //5) Currency Power Meter: ���� ���� ������ ��� ����� ���� �������.
   if(EURPower > USDPower && !isTest){
      trade = false;
   }
   //6) ��=15, ��=5
   // ������!
   
   //7) �� �5 ���� ��������� � ������� ����� ������ ���, ���� �� ��������. �� ����� �� ����� ������ ����� TMA.
   if(Close[0] < tmaM5Middle){
      trade = false; 
   }
   
   return(trade);
}

// ��������� ������ �� �������
void openBuyOrder(double lotSize){
   double stop = NormalizeDouble(Ask - (stopLossPips * Point),Digits);
   double take = NormalizeDouble(Ask + (profitPips * Point),Digits);
   OrderSend(Symbol(),OP_BUY, lotSize, Ask, 10, stop, take, "", EA_magic, 0, 0);
}

// ��������� ������ �� �������
void openSellOrder(double lotSize){
   double stop = NormalizeDouble(Bid + (stopLossPips * Point),Digits);
   double take = NormalizeDouble(Bid - (profitPips * Point),Digits);
   OrderSend(Symbol(),OP_SELL, lotSize, Bid, 10, stop, take, "", EA_magic, 0, 0);
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

   tmaM1Middle = iCustom(NULL,PERIOD_M1,"TMA with Distances", 
                  "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,0);
   tmaM1Middle4 = iCustom(NULL,PERIOD_M1,"TMA with Distances", 
                  "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,4);

   tmaM5Middle = iCustom(NULL,PERIOD_M5,"TMA with Distances", 
                  "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,0);
   tmaM5Middle4 = iCustom(NULL,PERIOD_M5,"TMA with Distances", 
                  "current time frame", 56, 0, 2.8, 100, true, false, false, false, false,false,false, 0,4);

   tmaM1Size = (tmaM1Up[0] - tmaM1Down[0]) / Point;
   tmaM5Size = (tmaM5Up[0] - tmaM5Down[0]) / Point;
   
   if(tmaM1Middle4 == tmaM1Middle){
      tmaM1Vector = MIDDLE;
   }
   
   if(tmaM1Middle > tmaM1Middle4){
      tmaM1Vector = UP;
   }else{
      tmaM1Vector = DOWN;
   }

   EURPower = iCustom(NULL,PERIOD_M1,"CurrencyPowerMeter_fixed_Graybit", 0,0);
   USDPower = iCustom(NULL,PERIOD_M1,"CurrencyPowerMeter_fixed_Graybit", 1,0);
   
   spreadSize = MathAbs(Bid-Ask);
} // end calculateNewVariables()

// ������ ������ ������
double calculateLotSize(){   
   double balance, riskBalance;
   
   // ���� �� ������� ����� ������� ������, �� ����� ������������� ��������
   if(!extUseMM){
      return(extFixLotSize);
   }
   
   if (IncludeOpenEquity) {
      balance = AccountEquity();
   }else {
      balance = AccountBalance();
   }

   // ��� ������� ������� ���������� 0
   if(balance == 0){
      return(0);
   }
   
   // ���-�� �����, ������� �� ������ ����������
   riskBalance = balance * (extRiskPercent / 100);
   
   // ������ ������, ����� ���������� ���� ����� ��� ����
   return(riskBalance / stopLossPips);
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
bool isNewsComming()
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

      NewsTime = false;
      // ���������, ���� ����� �� ������� ������ ��� ������, ��� �������, �� �������� ��������
      if (
         minutesUntilNextEvent <= MinsBeforeNews || 
         minutesSincePrevEvent <= MinsAfterNews
      ) {
          NewsTime = true;
      }
   }
   
   return(NewsTime);
}// end checkNews()