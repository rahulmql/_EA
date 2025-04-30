#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#property version "1.00"#include <trade/trade.mqh>


//Input variables

input int MagicNumber = 11111;
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15; //Enter Timeframe
input double LotSize = 0.01; //Enter Lot Size

input group "------ SL and TP setting ------";
input int SlPips = 100; // Enter SL in Pips
input int TpPips = 200; // Enter TP in Pips
//input double RiskPrcnt = 2; // Enter Risk Percentage

//---------------------------------------------------------------------------------

input group "------ Time Setting ------";
input string str4 = "";//*********** Time Zone GMT (If GMT is +2:30 / -2:30) *******************************
input int GMTHour_User = 5; // GMT Hour (2 / -2)
input int GMTMinute_User = 30; // GMT Minute (30 / -30)

input string str3 = "";//******************************* Candle Entry Time *******************************
input int EntryCandleHour = 5; //End Hour 
input int EntryCandleMinute = 30; //End Minute

input string str2 = "";//******************************* Start Time *******************************
input int StartTimeHour = 1; //Start Hour 
input int StartTimeMinute = 30; //Start Minute

input string str6 = "";//******************************* End Time *******************************
input int EndTimeHour = 10; //End Hour 
input int EndTimeMinute = 30; //End Minute

input group "------ MA Setting ------";
input int FastMaPeriod = 50; //Enter Fast MA Period
input int SlowMaPeriod = 200; //Enter Slow MA Period

input int AtrPeriod = 10; //Enter ATR Period


//Glogal Variables
CTrade trade;
double lot_size;
double barsTotal;

int entryCandleTime;
double targetCandleHigh;
double targetCandleLow;
double targetCandleFlag;

int handlerAtr;

int OnInit(){
//Initialization...................................
   lot_size = LotSize;
   barsTotal = iBars(_Symbol, Timeframe);
   
   entryCandleTime = EntryCandleHour*60 + EntryCandleMinute;
   targetCandleFlag = false;
  
//.................................................
   lot_size = LotSize;
   trade.SetExpertMagicNumber(MagicNumber);
   
   handlerAtr = iATR(NULL, Timeframe,AtrPeriod);
   
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason){
   
}


void OnTick() {
	int bars = iBars(_Symbol, Timeframe);
	
	if(!hasOpenPosition(MagicNumber) && targetCandleFlag){
	   executeMainLogic();
	}
	
	if(bars != barsTotal) {
		barsTotal = bars;
		
		//Getting Current Broker Time in IST
		datetime prevCandleOpenTime = iTime(_Symbol, Timeframe, 1);
     // Print("Previous candle open time: ", TimeToString(prevCandleOpenTime, TIME_DATE | TIME_MINUTES));
      
      datetime broker_to_ist_time = brokerToIstTime(prevCandleOpenTime);
     // Print("broker_to_ist_time : ", broker_to_ist_time);
		
		MqlDateTime tm = {};
   	TimeToStruct(broker_to_ist_time, tm);
   	int targetCandleTime = tm.hour*60 + tm.min;
   	
   	Print("targetCandleTime : ", targetCandleTime);
   	Print("entryCandleTime : ", entryCandleTime);
   	
   	if(targetCandleTime == entryCandleTime){
   	   targetCandleHigh = iHigh(_Symbol,Timeframe,1);
   	   targetCandleLow = iLow(_Symbol,Timeframe,1);
   	   targetCandleFlag = true;
   	}
		
	}
}
 
//Functions----------------------------------------------


//Execute Main Logic To Buy and Sell
void executeMainLogic(){
   if(checkTimeWithin(StartTimeHour,StartTimeMinute,EndTimeHour,EndTimeMinute)){
      double currCandleHigh = iHigh(_Symbol,Timeframe,0);
      double currCandleLow = iLow(_Symbol,Timeframe,0);
      
      double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
      
      if(currCandleHigh > targetCandleHigh){
         executeBuy(lot_size,askPrice,SlPips,TpPips);
         targetCandleFlag = false;
      }
      else if(currCandleLow < targetCandleLow){
         executeSell(lot_size,bidPrice,SlPips,TpPips);
         targetCandleFlag = false;
      }
   }
   else{
      Print("It is Belond Time Constrant : ", brokerToIstTime(iTime(_Symbol,Timeframe,0)));
   }
}

datetime brokerToIstTime(datetime brokerTime){
   // 5 hours 30 minutes in seconds
   int istOffset = 5 * 3600 + 30 * 60;

   // Add offset to broker/server time
   return brokerTime + istOffset;
}


int istToBrokerTime(int hour, int minute){
   return 1;
}

bool hasOpenPosition(int Magic_Number) {
	for(int i = 0; i < PositionsTotal(); i++) {
		if(PositionGetTicket(i)) {  // Must call this to select the position
			string symbol = PositionGetString(POSITION_SYMBOL);
			long magic   = PositionGetInteger(POSITION_MAGIC);

			if(symbol == _Symbol && magic == Magic_Number)
				return true;
		}
	}
	return false;
}



//Make a Buy order
void executeBuy(double lot, double entryPrice, double sl_Pips, double tp_Pips) {
   double slPipsPrice = pipsToPrice(_Symbol, sl_Pips);
   double tpPipsPrice = pipsToPrice(_Symbol, tp_Pips);
   double sl = entryPrice - slPipsPrice;
	double tp = entryPrice + tpPipsPrice;
	trade.Buy(lot, NULL, entryPrice, sl, tp, "Buy Order Placed");
}
//Make Sell order
void executeSell(double lot, double entryPrice, double sl_Pips, double tp_Pips) {
   double slPipsPrice = pipsToPrice(_Symbol, sl_Pips);
   double tpPipsPrice = pipsToPrice(_Symbol, tp_Pips);
   double sl = entryPrice + slPipsPrice;
	double tp = entryPrice - tpPipsPrice;
	trade.Sell(lot, NULL, entryPrice, sl, tp, "Sell Order Placed");
}

//Make a Buy order
void executeBuyLimit(double lot, double entryPrice, double sl_Pips, double tp_Pips) {
   double slPipsPrice = pipsToPrice(_Symbol, sl_Pips);
   double tpPipsPrice = pipsToPrice(_Symbol, tp_Pips);
   double sl = entryPrice - slPipsPrice;
	double tp = entryPrice + tpPipsPrice;
	trade.BuyLimit(lot,entryPrice,_Symbol, sl, tp,ORDER_TIME_GTC,0, "Buy Order Placed");
}
//Make Sell order
void executeSellLimit(double lot, double entryPrice, double sl_Pips, double tp_Pips) {
   double slPipsPrice = pipsToPrice(_Symbol, sl_Pips);
   double tpPipsPrice = pipsToPrice(_Symbol, tp_Pips);
   double sl = entryPrice + slPipsPrice;
	double tp = entryPrice - tpPipsPrice;
	trade.SellLimit(lot,entryPrice,_Symbol,sl,tp,ORDER_TIME_GTC,0, "Sell Order Placed");
}


//Calculate time 
bool checkTimeWithin(int st_hour, int st_minute, int et_hour, int et_minute) {
    // Calculate local time offset (assuming GMTHour_User and GMTMinute_User are defined)
    int localTimeOffsetGMT = GMTHour_User * 3600 + GMTMinute_User * 60; // in seconds
    
    // Get current GMT time and adjust to user's local time
    datetime userLocalTime = TimeGMT() + localTimeOffsetGMT;
    
    // Extract hour and minute from the adjusted time
    MqlDateTime tm;
    TimeToStruct(userLocalTime, tm);
    
    int curr_hour = tm.hour;
    int curr_min = tm.min;
    
    // Convert all times to total minutes since midnight for accurate comparison
    int currentTotalMinutes = curr_hour * 60 + curr_min;
    int startTotalMinutes = st_hour * 60 + st_minute;
    int endTotalMinutes = et_hour * 60 + et_minute;
    
    // Handle overnight time ranges (e.g., 23:00 to 01:00)
    if (endTotalMinutes <= startTotalMinutes) {
        // Case where end time is on the next day (e.g., 23:00 to 01:00)
        return (currentTotalMinutes >= startTotalMinutes) || (currentTotalMinutes <= endTotalMinutes);
    } else {
        // Normal case (e.g., 09:00 to 17:00)
        return (currentTotalMinutes >= startTotalMinutes) && (currentTotalMinutes <= endTotalMinutes);
    }
}


//Moving Average
double getMAValue(ENUM_MA_METHOD maType,int maPeriod,ENUM_TIMEFRAMES time_frame, int shift=0,int count=1){  //Calculate fast EMA value
   int handleMa;
   handleMa = iMA(_Symbol,time_frame,maPeriod,0,maType,PRICE_CLOSE);
   double ma[];
   CopyBuffer(handleMa,0,shift,count,ma);
   return NormalizeDouble(ma[0],_Digits);
}

//atr Indicater

double getAtrValue(int shift=0, int count=1){
   double atr[];
   CopyBuffer(handlerAtr,0,shift,count,atr);   
   return atr[0];
}


//| Convert Points to Price for Any Symbol                          
double pipsToPrice(string symbol, double pips) {
	if(symbol == NULL) symbol = Symbol();
	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
	int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
	// Handle special cases
	// Metals typically use 0.01 as pip size (2 decimal places)
	if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "XAG") != -1) {
		if(digits == 2)
			//vPoint = 0.1;
			return NormalizeDouble(point * pips * 10, digits);
		else return NormalizeDouble(point * pips * 10 * 10, digits);
	}
	//handling 3 point jpy
	else
	if(digits == 3) {
		return NormalizeDouble(point * pips * 10, digits);
	}
	//Handling 2 pont Bitcoin
	else
	if(StringFind(symbol, "BTC") != -1) {
		return NormalizeDouble(point * pips * 10 * 100, digits);
	}
	// all other
	else {
		return NormalizeDouble(point * pips * 10, digits);
	}
	return NormalizeDouble(point * pips * 10, digits);
}









   			   //executeBuyLimit(lot_size, askPrice - pipsToPrice(_Symbol,SlPips*0.2), SlPips-SlPips*0.2, TpPips+SlPips*0.2);
   			   //executeBuyLimit(lot_size,askPrice - pipsToPrice(_Symbol,SlPips*0.4), SlPips-SlPips*0.4, TpPips+SlPips*0.4);
   			   //executeBuyLimit(lot_size,askPrice - pipsToPrice(_Symbol,SlPips*0.6), SlPips-SlPips*0.6, TpPips+SlPips*0.6);
   			   //executeBuyLimit(lot_size,askPrice - pipsToPrice(_Symbol,SlPips*0.9), SlPips-SlPips*0.9, TpPips+SlPips*0.9);









   			   //executeSellLimit(lot_size, bidPrice + pipsToPrice(_Symbol,SlPips*0.2), SlPips-SlPips*0.2, TpPips+SlPips*0.2);
   			   //executeSellLimit(lot_size,bidPrice + pipsToPrice(_Symbol,SlPips*0.4), SlPips-SlPips*0.4, TpPips+SlPips*0.4);
   			   //executeSellLimit(lot_size,bidPrice + pipsToPrice(_Symbol,SlPips*0.6), SlPips-SlPips*0.6, TpPips+SlPips*0.6);
   			   //executeSellLimit(lot_size,bidPrice + pipsToPrice(_Symbol,SlPips*0.9), SlPips-SlPips*0.9, TpPips+SlPips*0.9);