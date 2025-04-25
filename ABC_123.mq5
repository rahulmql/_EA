//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <trade/trade.mqh>

#include <Trade\PositionInfo.mqh>

//Input Variables

input int Magic = 112233; //Magic Number
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15;

enum lotType
  {
   Risk, // Risk%
   Fixed // Fixed Lot
  };
input lotType selectLot=Risk;


input double LotSize = 0.01; //Lot Size
input int PeriodEma = 50; //EMA Period

input int SlPips = 10; // SL in points
input int TpPips = 50; // TP in points
//input double TakeProfit=1.5; // Take Profit Ratio (eg: 1:2)

input int RiskPercentage = 2; // Enter Risk Percentage

input bool useBreakEven=true; // Use Break Even
input double PartialClose =25;// Partial Close %


//Global Variables
CTrade trade;
CPositionInfo  m_position;
double vPoint;
int barsTotal = iBars(_Symbol,Timeframe);
int handleEma;

int totalLossTradeCons = 0;
int totalProfitCons = 0;

double TakeProfit;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   handleEma = iMA(_Symbol,Timeframe,PeriodEma,0,MODE_EMA,PRICE_CLOSE);
   TakeProfit = TpPips/SlPips;
   
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

   if(useBreakEven)
     {
      Modify();
     }

   int bar = iBars(_Symbol,Timeframe);

   if(bar != barsTotal)
     {
      barsTotal = bar;

      if(!hasOpenPosition())
        {

         double ema_current, ema_previou;

         ema_current = getEma(0);
         ema_previou = getEma(1);

         double askPrice = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
         double bidPrice = SymbolInfoDouble(_Symbol,SYMBOL_BID);

         double slPipsPrice = pointsToPrice(_Symbol,SlPips);
         double tpPipsPrice = pointsToPrice(_Symbol,TpPips);

         // Get symbol information
         string symbol = Symbol();
         double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double lotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
         double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);


         //double lot_size = CalculateLotSize(RiskPercentage,SlPips);
         double lot_size;



         if(ema_current < askPrice)
           {

            double sl = askPrice - slPipsPrice;
            double tp = askPrice + tpPipsPrice;


            Print("Tick Size : ", tickSize);
            Print("Tick Value : ", tickValue);
            Print("lotSize min : ", lotSize);
            Print("Contract Soze : ", contractSize);

            Print("Lot Size Our : ", lot_size);

            lot_size = LotSizeCalc(sl,askPrice);

            //executeSell(askPrice,tp,sl);
            executeBuy(lot_size,askPrice,sl,tp);
           }

         else
            if(ema_current > bidPrice)
              {
               double sl = bidPrice + pointsToPrice(_Symbol,SlPips);
               double tp = bidPrice - pointsToPrice(_Symbol,TpPips);

               lot_size = LotSizeCalc(sl,bidPrice);

               //executeBuy(bidPrice,tp,sl);
               executeSell(lot_size,bidPrice,sl,tp);
              }


        }
     }
  }



//|                                                                  |
//+------------------------------------------------------------------+
void Modify()
{
   if(PartialClose <= 0) return;

   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!m_position.SelectByIndex(i)) continue;

      if(m_position.Symbol() != _Symbol || m_position.Magic() != Magic) continue;

      double openPrice = m_position.PriceOpen();
      double stopLoss = m_position.StopLoss();
      double currentPrice = m_position.PriceCurrent();
      double volume = m_position.Volume();
      double closeVolume = NormalizeDouble(volume * (PartialClose / 100.0), (int)MathLog10(1.0 / volumeStep));

      if(m_position.PositionType() == POSITION_TYPE_BUY)
      {
         if(stopLoss < openPrice)
         {
            double pipsdif = MathAbs(openPrice - stopLoss);
            if(currentPrice > openPrice + pipsdif)
            {
               if(!trade.PositionClosePartial(m_position.Ticket(), closeVolume))
                  Print("Partial close failed (Buy): ", trade.ResultRetcodeDescription());

               if(!trade.PositionModify(m_position.Ticket(), openPrice, m_position.TakeProfit()))
                  Print("Modify failed (Buy): ", trade.ResultRetcodeDescription());
            }
         }
      }
      else if(m_position.PositionType() == POSITION_TYPE_SELL)
      {
         if(stopLoss > openPrice)
         {
            double pipsdif = MathAbs(openPrice - stopLoss);
            if(currentPrice < openPrice - pipsdif)
            {
               if(!trade.PositionClosePartial(m_position.Ticket(), closeVolume))
                  Print("Partial close failed (Sell): ", trade.ResultRetcodeDescription());

               if(!trade.PositionModify(m_position.Ticket(), openPrice, m_position.TakeProfit()))
                  Print("Modify failed (Sell): ", trade.ResultRetcodeDescription());
            }
         }
      }
   }
}



//+------------------------------------------------------------------+
double LotSizeCalc(double slPrice, double entryPrice)
  {
   if(selectLot == Fixed)
      return LotSize;

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




//Get Ema Value
double getEma(int startIdx=0)
  {
   double ema[];
   CopyBuffer(handleEma,0,startIdx,1,ema);
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
