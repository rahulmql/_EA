//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <trade/trade.mqh>

//Input Variables

input int Magic = 112233; //Magic Number
input ENUM_TIMEFRAMES Timeframe = PERIOD_M30;

input group "------ Lot Setting ------";
enum lotType
  {
   Risk, // Risk%
   Fixed // Fixed Lot
  };
input lotType selectLot=Fixed;
input double LotSize = 0.01; //Lot Size

input group "------ EMA Setting ------";
input int PeriodEmaFast = 50; //Fast EMA Period
input int PeriodEmaSlow = 35; //Slow EMA Period

input group "------ SL and TP Setting ------";
input int SlPips = 30; // SL in points
input int TpPips = 30; // TP in points
input int RiskPercentage = 2; // Enter Risk Percentage 


//Global Variables
CTrade trade;
double vPoint;
int barsTotal = iBars(_Symbol,Timeframe);
int handleEmaFast;
int handleEmaSlow;

int totalLossTradeCons = 0;
int totalProfitCons = 0;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   handleEmaFast = iMA(_Symbol,Timeframe,PeriodEmaFast,0,MODE_EMA,PRICE_CLOSE);
   handleEmaSlow = iMA(_Symbol,PERIOD_M4,PeriodEmaSlow,0,MODE_SMA,PRICE_CLOSE);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

   int bar = iBars(_Symbol,Timeframe);

   if(bar != barsTotal)
     {
      barsTotal = bar;

      if(!hasOpenPosition())
        {

         double ema_fast_current, ema_fast_previou;
         double ema_slow_current, ema_slow_previou;

         ema_fast_current = getEmaFast(0);
         ema_fast_previou = getEmaFast(1);
         
         ema_slow_current = getEmaSlow(0);
         ema_slow_previou = getEmaSlow(1);

         double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);
         double spread = SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
         
         
         double slPipsPrice = pointsToPrice(_Symbol,SlPips);
         double tpPipsPrice = pointsToPrice(_Symbol,TpPips);
         double lot_size;
         
         if(ema_fast_previou < ema_slow_previou)
           {
            
            double sl = askPrice - slPipsPrice;
            double tp = askPrice + tpPipsPrice;
           
           
           lot_size = LotSizeCalc(sl,askPrice);
               int a = 1/lot_size;
               spread = spread/a;
               spread *=3 ;
           
           
           if(GetLastClosedTradePL(Magic) > 0){
               executeSell(lot_size,askPrice,tp,sl-spread);
               
           }
           else{
               executeBuy(lot_size,askPrice,sl,tp-spread);
           }
           
            
            //executeBuy(lot_size,askPrice,sl,tp);
            
            
            
           }

         else
            if(ema_fast_previou < ema_slow_previou)
              {
               double sl = bidPrice + pointsToPrice(_Symbol,SlPips);
               double tp = bidPrice - pointsToPrice(_Symbol,TpPips);
               
               lot_size = LotSizeCalc(sl,bidPrice);
               int a = 1/lot_size;
               spread = spread/a;
               spread *= 5;
               
               if(GetLastClosedTradePL(Magic) < 0){
                  
                  executeBuy(lot_size,bidPrice,tp,sl-spread);
               }
               else{
                   executeSell(lot_size,bidPrice,sl,tp-spread);
               }

               
               //executeSell(lot_size,bidPrice,sl,tp);
              }


        }
     }
  }


//+------------------------------------------------------------------+
double LotSizeCalc(double slPrice, double entryPrice)
{
   if(selectLot == Fixed) return LotSize;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercentage / 100.0);
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double priceDiff = MathAbs(entryPrice - slPrice);
   
   
   
   double lots = (riskAmount / (priceDiff / pointSize)) / pointValue;
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lots = MathRound(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Convert Points to Price for Any Symbol                           |
//+------------------------------------------------------------------+
double pointsToPrice(string symbol, double pips)
  {
   if(symbol==NULL)
      symbol = Symbol();

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

// Handle special cases

// Metals typically use 0.01 as pip size (2 decimal places)
   if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "XAG") != -1)
     {
      if(digits == 2)
         //vPoint = 0.1;
         return NormalizeDouble(point*pips*10,digits);
      else
         return NormalizeDouble(point*pips*10 *10,digits);
     }
//handling 3 point jpy
   else
      if(digits == 3)
        {
         return NormalizeDouble(point*pips*10,digits);
        }
      //Handling 2 pont Bitcoin
      else
         if(StringFind(symbol,"BTC") != -1)
           {
            return NormalizeDouble(point*pips*10*100,digits);
           }
         // all other
         else
           {
            return NormalizeDouble(point*pips*10,digits);
           }
   return NormalizeDouble(point*pips*10,digits);
  }




//Get Ema fast Value
double getEmaFast(int startIdx=0)
  {
   double ema[];
   CopyBuffer(handleEmaFast,0,startIdx,1,ema);
   double value = ema[0];
   value = NormalizeDouble(value,_Digits);
   return value;
  }
  
  
//Get Ema Slow Value
double getEmaSlow(int startIdx=0)
  {
   double ema[];
   CopyBuffer(handleEmaSlow,0,startIdx,1,ema);
   double value = ema[0];
   value = NormalizeDouble(value,_Digits);
   return value;
  }



//Check Position opene
bool hasOpenPosition()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong positionTicket = PositionGetTicket(i);
      if(PositionGetSymbol(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC))
         return true;
     }
   return false;
  }



//Make a Buy order
void executeBuy(double lot_size,double entry, double sl=0, double tp=0)
  {
   entry = NormalizeDouble(entry,_Digits);
   trade.Buy(lot_size,NULL,entry,sl,tp,"Buy Order Placed");
  }


//Make Sell order
void executeSell(double lot_size,double entry, double sl=0, double tp=0)
  {
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLastClosedTradePL(int magicNumber)
  {
// Load history data
   HistorySelect(0, TimeCurrent());

// Get total number of deals in history
   int totalDeals = HistoryDealsTotal();

   if(totalDeals == 0)
      return 0; // No history available

// Get the last deal ticket
   ulong lastDealTicket = HistoryDealGetTicket(totalDeals - 1);

   if(lastDealTicket == 0)
      return 0;

// Check if this was a closing deal
   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(lastDealTicket, DEAL_ENTRY);

   if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY && HistoryDealGetInteger(lastDealTicket, DEAL_MAGIC) != magicNumber)
     {
      // Return the profit of the closing deal
      return HistoryDealGetDouble(lastDealTicket, DEAL_PROFIT);
     }

   return 0; // No closing deal found
  }



//+------------------------------------------------------------------+
