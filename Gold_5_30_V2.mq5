//+------------------------------------------------------------------+
//|                                                 gold_5_30_am.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"#include <trade/trade.mqh>

//Input variables
input int MagicNumber = 11111;
input ENUM_TIMEFRAMES Timeframe = PERIOD_M15; //Enter Timeframe
input double LotSize = 0.01; //Enter Lot Size
input int SLPips = 100; // Enter SL in Pips
input int TPPips = 200; // Enter TP in Pips
input double RiskPrcnt = 2; // Enter Risk Percentage
//input int NumberOfLastNCandle = 14; //Enter last N candle For SL
input string Abc = ""; //************ Traing and Breakeven Setting ************
input int TrailingPips = 100; //Enter Trailing SL
//input int BreakEvenPips = 25; //Enter BreakEven Pips
input double StepsInPips = 10; //Enter Trailing Steps Pips
input bool Trailing_flag = true; //Yes/No
input string Abcd = ""; //************ Candle Time to Trade on BreakOut ************
input int CandleCloseTimeHour = 5; //Enter Hour
input int CandleCloseTimeMinute = 30; //Enter Minute
input string ABc = ""; //************ Last Time to Take Trade Within ************
input int TimeCapHour = 10; //Enter Hour
input int TimeCapMinute = 0; //Enter Minute
input string abc = ""; //************ Set Moving Averages Cross Over For Confirmation ************
input ENUM_MA_METHOD MA_Method_Fast = MODE_EMA; // Select Fast Moving Average 
input int MA_Period_Fast = 9; // Enter Fast MA Period
input ENUM_MA_METHOD MA_Method_Slow = MODE_SMA; // Select Slow Moving Average 
input int MA_Period_Slow = 9; // Enter Fast MA Period
input bool MA_Confirmation = true; // YES/No  
//input string abcc ="";//************ ChatGPT INPUT FIelds ************
// Input Parameters (place these at the top of your EA)
//input double  TrailingStopPips = 50;      // Trailing SL in pips
//input double  StepsInPips      = 10;      // Minimum step size in pips for trailing
//input double  breakevenPips    = 30;      // Breakeven activation level in pips
//input double  breakevenBuffer  = 2;       // Buffer to secure some profit at breakeven
//input bool    EnableTSLDebug   = false;   // Debug print on SL changes
//Glogal Variables
CTrade trade;
long entryTime;
long exitTime;
double candleCloseHigh;
double candleCloseLow;
int barsTotal = iBars(NULL, Timeframe);
int handleMa_Fast;
int handleMa_Slow;
//OnInIt Function
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
	trade.SetExpertMagicNumber(MagicNumber);
	entryTime = (CandleCloseTimeHour * 3600) + (CandleCloseTimeMinute * 60);
	exitTime = (TimeCapHour * 3600) + (TimeCapMinute * 60);
	handleMa_Fast = iMA(_Symbol, Timeframe, MA_Period_Fast, 0, MODE_EMA, PRICE_CLOSE);
	handleMa_Slow = iMA(_Symbol, Timeframe, MA_Period_Slow, 0, MODE_SMA, PRICE_CLOSE);
	return (INIT_SUCCEEDED);
}
//OnDeInit Function
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
	IndicatorRelease(handleMa_Fast);
	IndicatorRelease(handleMa_Slow);
}
//OnTick Function
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick() {
	int bars = iBars(NULL, Timeframe);
	if(bars != barsTotal) {
		barsTotal = bars;
		if(hasOpenPosition() && Trailing_flag) {
			//TrailingStopWithBreakeven(_Symbol,MagicNumber,TrailingPips,BreakEvenPips,StepsInPips);
			//TrailingStopWithBreakeven();
			TrailingStop(_Symbol, MagicNumber, TrailingPips, 10);
		}
		//check position not opened and it within Time resistance
		if(!hasOpenPosition() && checkTimeForEntry(entryTime, exitTime)) {
			double op = iOpen(_Symbol, Timeframe, 1);
			double clPrice = iClose(_Symbol, Timeframe, 1);
			if(clPrice > candleCloseHigh) {
				if(MA_Confirmation) {
					if(checkMACrossOverForBuy()) executeBuy();
				} else executeBuy();
			} else
			if(clPrice < candleCloseLow) {
				if(MA_Confirmation) {
					if(checkMACrossOverForSell()) executeSell();
				} else executeSell();
			}
		}
	}
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int brokerTimeToLocalTimeCon(int BT) {
	int timeDiff = int(TimeCurrent() - TimeLocal());
	int BT_to_LT = BT - timeDiff;
	return BT_to_LT;
}
//Check Entry Time for Entry 
bool checkTimeForEntry(long CandleCloseTime, long TimeCap) {
	int candOpenPrev = int(iTime(_Symbol, Timeframe, 1));
	int candClosePrev = int(iTime(_Symbol, Timeframe, 0));
	int currTime = (int) TimeLocal();
	candClosePrev = brokerTimeToLocalTimeCon(candClosePrev);
	//currTime = brokerTimeToLocalTimeCon(currTime);
	MqlDateTime tm = {};
	TimeToStruct(candClosePrev, tm);
	candClosePrev = tm.hour * 3600 + tm.min * 60;
	TimeToStruct(currTime, tm);
	currTime = tm.hour * 3600 + tm.min * 60;
	if(candClosePrev >= CandleCloseTime && candClosePrev < CandleCloseTime + PeriodSeconds(Timeframe)) {
		candleCloseHigh = iHigh(_Symbol, Timeframe, 1);
		candleCloseLow = iLow(_Symbol, Timeframe, 1);
	}
	if(currTime >= CandleCloseTime && currTime < TimeCap) return true;
	return false;
}
//Moving Average Cross over check
bool checkMACrossOverForBuy() {
	double fastMA_Current = getFastMAValue(0);
	double fastMA_Previous = getFastMAValue(1);
	double slowMA_Current = getSlowMAValue(0);
	double slowMA_Previous = getSlowMAValue(1);
	if(fastMA_Previous < slowMA_Previous && fastMA_Current > slowMA_Current) {
		return true;
	}
	return false;
}
bool checkMACrossOverForSell() {
	double fastMA_Current = getFastMAValue(0);
	double fastMA_Previous = getFastMAValue(1);
	double slowMA_Current = getSlowMAValue(0);
	double slowMA_Previous = getSlowMAValue(1);
	if(fastMA_Previous > slowMA_Previous && fastMA_Current < slowMA_Current) {
		return true;
	}
	return false;
}
//Check, is already position opened by this EA
bool hasOpenPosition() {
	for(int i = 0; i < PositionsTotal(); i++) {
		ulong positionTicket = PositionGetTicket(i);
		if(PositionGetSymbol(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC)) return true;
	}
	return false;
}
//Make a Buy order
void executeBuy() {
	double lot_size = CalculateLotSize(SLPips, RiskPrcnt);
	double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
	entry = NormalizeDouble(entry, _Digits);
	double sl = entry - CalculatePipsAdvanced(_Symbol, SLPips);
	double tp = entry + CalculatePipsAdvanced(_Symbol, TPPips);
	trade.Buy(lot_size, NULL, entry, sl, tp, "Buy Order Placed");
}
//Make Sell order
void executeSell() {
	double lot_size = CalculateLotSize(SLPips, RiskPrcnt);
	double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
	entry = NormalizeDouble(entry, _Digits);
	double sl = entry + CalculatePipsAdvanced(_Symbol, SLPips);
	double tp = entry - CalculatePipsAdvanced(_Symbol, TPPips);
	trade.Sell(lot_size, NULL, entry, sl, tp, "Sell Order Placed");
}
//make a SL for long position, low of last n candle
double slBuy_LastNCandle(int candleCount) {
	double lowPrice[];
	CopyLow(_Symbol, Timeframe, 0, candleCount, lowPrice);
	int lowPriceIndex = ArrayMinimum(lowPrice);
	double sl = lowPrice[lowPriceIndex];
	sl = NormalizeDouble(sl, _Digits);
	return sl;
}
//Make SL for Short Postion, High of last N candle
double slSell_LastNCandle(int candleCount) {
	double highPrice[];
	CopyHigh(_Symbol, Timeframe, 0, candleCount, highPrice);
	int highPriceIndex = ArrayMaximum(highPrice);
	double sl = highPrice[highPriceIndex];
	sl = NormalizeDouble(sl, _Digits);
	return sl;
}
//+------------------------------------------------------------------+
//Calculating Pips by Points
double CalculatePipsAdvanced(string symbol, int pricePips) {
	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
	int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
	int priceChangeInPoints;
	if(digits == 2) {
		priceChangeInPoints = pricePips * 10;
	} else if(digits == 3) {
		priceChangeInPoints = pricePips * 100;
	} else {
		priceChangeInPoints = pricePips * 10;
	}
	double priceChange = priceChangeInPoints * point;
	priceChange = NormalizeDouble(priceChange, digits);
	return priceChange;
}
//Calculate fast SMA value
double getFastMAValue(int shift) {
	double fma[];
	CopyBuffer(handleMa_Fast, 0, shift, 1, fma);
	return NormalizeDouble(fma[0], _Digits);
}
//Get slow SMA value
double getSlowMAValue(int shift) {
	double sma[];
	CopyBuffer(handleMa_Slow, 0, shift, 1, sma);
	return NormalizeDouble(sma[0], _Digits);
}
//+------------------------------------------------------------------+
//| Function to calculate lot size based on risk management          |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPips, double riskPercent) {
	// Get account balance
	double balance = AccountInfoDouble(ACCOUNT_BALANCE);
	// Get symbol information
	string symbol = Symbol();
	double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
	double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
	double lotSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
	// Calculate pip value (adjust for 5-digit brokers)
	double pipSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
	if(Digits() == 3 || Digits() == 5) pipSize *= 10;
	// Calculate monetary risk
	double riskAmount = balance * (riskPercent / 100);
	// Calculate lot size
	double moneyRiskPerLot = stopLossPips * pipSize * lotSize * tickValue / tickSize;
	double lots = riskAmount / moneyRiskPerLot;
	// Normalize and validate lot size
	double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
	double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
	double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
	lots = MathRound(lots / lotStep) * lotStep;
	lots = MathMax(minLot, MathMin(maxLot, lots));
	return lots;
}
//+------------------------------------------------------------------+
//| Modify Position with new SL/TP                                   |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp, string symbol) {
	// Create request and result objects
	MqlTradeRequest request = {};
	MqlTradeResult result = {};
	request.action = TRADE_ACTION_SLTP;
	request.position = ticket;
	request.symbol = symbol;
	request.sl = sl;
	request.tp = tp;
	// Send modification request
	bool success = OrderSend(request, result);
	if(!success) {
		Print("Failed to modify position #", ticket, " Error: ", GetLastError());
		return false;
	}
	return true;
}
//+------------------------------------------------------------------+
//| Trailing Stop Function                                           |
//+------------------------------------------------------------------+
void TrailingStop(string symbol, int magicNumber, int trailPips, double stepPips = 10.0) {
	// Adjust for 5-digit brokers
	double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
	int digits = (int) SymbolInfoInteger(symbol, SYMBOL_DIGITS);
	double multiplier = (digits == 3 || digits == 5) ? 10 : 1;
	double trailPoints = trailPips * multiplier * point;
	double stepPoints = stepPips * multiplier * point;
	// Check all open positions
	for(int i = PositionsTotal() - 1; i >= 0; i--) {
		ulong ticket = PositionGetTicket(i);
		if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == symbol) {
			// Check magic number if needed
			if(magicNumber != 0 && PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;
			double currentSL = PositionGetDouble(POSITION_SL);
			double currentTP = PositionGetDouble(POSITION_TP);
			double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
			double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
			// Calculate new stop loss
			double newSL = 0;
			if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
				newSL = currentPrice - trailPoints;
				if(currentSL < newSL - stepPoints || currentSL == 0) {
					ModifyPosition(ticket, newSL, currentTP, symbol);
				}
			} else // POSITION_TYPE_SELL
			{
				newSL = currentPrice + trailPoints;
				if(currentSL > newSL + stepPoints || currentSL == 0) {
					ModifyPosition(ticket, newSL, currentTP, symbol);
				}
			}
		}
	}
}