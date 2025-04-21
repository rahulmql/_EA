#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <trade/trade.mqh>

//Input Variables

input int Magic = 112233; //Magic Number
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;
input double LotSize = 0.01; //Lot Size
input int PeriodEma = 50; //EMA Period

input int SlPips = 10; // SL in points 
input int TpPips = 50; // TP in points 



//Global Variables
CTrade trade;
double _Vpoint;
int barsTotal = iBars(_Symbol,Timeframe);
int handleEma;

int totalLossTradeCons = 0;
int totalProfitCons = 0;


int OnInit(){
   trade.SetExpertMagicNumber(Magic);
   handleEma = iMA(_Symbol,Timeframe,PeriodEma,0,MODE_EMA,PRICE_CLOSE);
   return(INIT_SUCCEEDED);
}
  
void OnDeinit(const int reason){
   
}

void OnTick(){
   
   int bar = iBars(_Symbol,Timeframe);
   
   if(bar != barsTotal){
      barsTotal = bar;
      
      if( !hasOpenPosition()){
      
         double ema_current, ema_previou;
         
         ema_current = getEma(0);
         ema_previou = getEma(1);
         
         double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         
         if(GetLastClosedTradePL(Magic) < 0 ){
            
            totalLossTradeCons++;
            
         }
         //else if(GetLastClosedTradePL(Magic) > 0){}
         
         if(totalLossTradeCons == 2){
            double tp = bidPrice + pointsToPrice(_Symbol,SlPips);
            double sl = bidPrice - pointsToPrice(_Symbol,TpPips);
            
            double lot = LotSize * totalLossTradeCons;
            totalLossTradeCons = 0;
            
            executeBuy(lot,askPrice,sl,tp);
         }
         else {
            
            if(ema_current < askPrice){
            double sl = askPrice - pointsToPrice(_Symbol,SlPips);
            double tp = askPrice + pointsToPrice(_Symbol,TpPips);
            
            //executeSell(askPrice,tp,sl);
            executeBuy(LotSize,askPrice,sl,tp);
         }
         
         else if(ema_current > bidPrice){
            double sl = bidPrice + pointsToPrice(_Symbol,SlPips);
            double tp = bidPrice - pointsToPrice(_Symbol,TpPips);
            
            //executeBuy(bidPrice,tp,sl);
            executeSell(LotSize,bidPrice,sl,tp);
         }
            
         }
         
      }         
         
   }
}

double CalculateLotSize(
   double riskPercentage,
   double stopLossPoints,
   string symbol = NULL
) {
   if (symbol == NULL) symbol = Symbol();
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if (accountBalance <= 0) {
      Print("Error: Account balance is zero or negative!");
      return 0.0;
   }

   double riskAmount = accountBalance * (riskPercentage / 100.0);

   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if (tickSize <= 0 || tickValue <= 0) {
      Print("Error: Invalid tick size or tick value!");
      return 0.0;
   }

   double moneyAtRiskPerLot = stopLossPoints * tickValue / tickSize;
   if (moneyAtRiskPerLot <= 0) {
      Print("Error: Invalid stop loss points or risk calculation!");
      return 0.0;
   }

   double lots = riskAmount / moneyAtRiskPerLot;

   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   lots = MathRound(lots / lotStep) * lotStep;
   lots = NormalizeDouble(lots, (int)MathLog10(1.0/lotStep));

   return lots;
}

//+------------------------------------------------------------------+
//| Convert Points to Price for Any Symbol                           |
//+------------------------------------------------------------------+
double pointsToPrice(string symbol, double pips)
  {
   if(symbol==NULL) symbol = Symbol();
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Handle special cases
    
    // Metals typically use 0.01 as pip size (2 decimal places)
    if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "XAG") != -1){
      if(digits == 2) return NormalizeDouble(point*pips*10,digits);
      else return NormalizeDouble(point*pips*10 *10,digits);
    }
    //handling 3 point jpy
    else if(digits == 3){
      return NormalizeDouble(point*pips*10,digits);
    }
    //Handling 2 pont Bitcoin
    else if(StringFind(symbol,"BTC") != -1){
      return NormalizeDouble(point*pips*10*100,digits);
    }
    // all other 
    else{
      return NormalizeDouble(point*pips*10,digits);
    }
    return NormalizeDouble(point*pips*10,digits);
  }




//Get Ema Value
double getEma(int startIdx=0){
   double ema[];
   CopyBuffer(handleEma,0,startIdx,1,ema);
   double value = ema[0];
   value = NormalizeDouble(value,_Digits);
   return value;
}



//Check Position opene
bool hasOpenPosition(){
   for(int i = 0; i < PositionsTotal(); i++){
      ulong positionTicket = PositionGetTicket(i);
      if(PositionGetSymbol(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC))
         return true;
   }
   return false;
}



//Make a Buy order
void executeBuy(double lot_size,double entry, double sl=0, double tp=0){
   entry = NormalizeDouble(entry,_Digits);
   trade.Buy(lot_size,NULL,entry,sl,tp,"Buy Order Placed");
}


//Make Sell order
void executeSell(double lot_size,double entry, double sl=0, double tp=0){
   entry = NormalizeDouble(entry,_Digits);
   trade.Sell(lot_size,NULL,entry,sl,tp,"Sell Order Placed");
}


//make a SL for long position, low of last n candle
double lowOfLastNCandle(int candleCount, ENUM_TIMEFRAMES timeframe)
  {
   double lowPrice[];
   CopyLow(_Symbol,timeframe,0,candleCount,lowPrice);
   int lowPriceIndex = ArrayMinimum(lowPrice);
   double low = lowPrice[lowPriceIndex];
   low = NormalizeDouble(low,_Digits);
   return low;
  }

//Make SL for Short Postion, High of last N candle
double highOfLastNCandle(int candleCount, ENUM_TIMEFRAMES timeframe)
  {
   double highPrice[];
   CopyHigh(_Symbol,timeframe,0,candleCount,highPrice);
   int highPriceIndex = ArrayMaximum(highPrice);
   double high = highPrice[highPriceIndex];
   high = NormalizeDouble(high, _Digits);
   return high;
  }
  
  double GetLastClosedTradePL(int magicNumber)
{
    // Load history data
    HistorySelect(0, TimeCurrent());
    
    // Get total number of deals in history
    int totalDeals = HistoryDealsTotal();
    
    if(totalDeals == 0) return 0; // No history available
    
    // Get the last deal ticket
    ulong lastDealTicket = HistoryDealGetTicket(totalDeals - 1);
    
    if(lastDealTicket == 0) return 0;
    
    // Check if this was a closing deal
    ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(lastDealTicket, DEAL_ENTRY);
    
    if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY && HistoryDealGetInteger(lastDealTicket, DEAL_MAGIC) != magicNumber)
    {
        // Return the profit of the closing deal
        return HistoryDealGetDouble(lastDealTicket, DEAL_PROFIT);
    }
    
    return 0; // No closing deal found
}



