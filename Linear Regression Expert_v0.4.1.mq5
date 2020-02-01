//+------------------------------------------------------------------+
//|                                     Linear Regression Expert.mq5 |
//+------------------------------------------------------------------+

#property version   "1.30"
#include <Charts\Chart.mqh>
#include <Trade\Trade.mqh>


input double MaximumRisk        = 0.02;    // Maximum Risk in percentage
input double DecreaseFactor     = 3;       // Descrease factor
input int    fastLRPeriod       = 89;      // fast Linear Regression period
input int    LRTunnel1          = 144;     //   Linear Legression
input int    LRTunnel2          = 169;     //   Tunnel 1-2
input int    MATunnel1          = 144;     //   Moving Avarage
input int    MATunnel2          = 169;     //   Tunnel 1-2
//---
int   fastLRHandle=0;
int   LRTunnel1Handle=0;
int   LRTunnel2Handle=0;
int   MATunnel1Handle=0;
int   MATunnel2Handle=0;

//+------------------------------------------------------------------+
//| Calculate optimal lot size                                       |
//+------------------------------------------------------------------+
double TradeSizeOptimized(void)
  {
   double price=0.0;
   double margin=0.0;
//--- select lot size
   if(!SymbolInfoDouble(_Symbol,SYMBOL_ASK,price))               return(0.0);
   if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,1.0,price,margin)) return(0.0);
   if(margin<=0.0)                                               return(0.0);

   double lot=NormalizeDouble(AccountInfoDouble(ACCOUNT_FREEMARGIN)*MaximumRisk/margin,2);
//--- calculate number of losses orders without a break
   if(DecreaseFactor>0)
     {
      //--- select history for access
      HistorySelect(0,TimeCurrent());
      //---
      int    orders=HistoryDealsTotal();  // total history deals
      int    losses=0;                    // number of losses orders without a break

      for(int i=orders-1;i>=0;i--)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0)
           {
            Print("HistoryDealGetTicket failed, no trade history");
            break;
           }
         //--- check symbol
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol) continue;
         //--- check profit
         double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         if(profit>0.0) break;
         if(profit<0.0) losses++;
        }
      //---
      if(losses>1) lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
     }
//--- normalize and check limits
   double stepvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=stepvol*NormalizeDouble(lot/stepvol,0);

   double minvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lot<minvol) lot=minvol;

   double maxvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(lot>maxvol) lot=maxvol;
//--- return trading volume
   return(lot);
  }
//+------------------------------------------------------------------+
//| Check for open position conditions                               |
//+------------------------------------------------------------------+
void CheckForOpen()
  {
   MqlRates rt[2];
//--- go trading only for first ticks of new bar
   if(CopyRates(_Symbol,_Period,0,2,rt)!=2)
     {
      Print("CopyRates of ",_Symbol," failed, no history");
      return;
     }
   if(rt[1].tick_volume>1) return;
//--- get current indicator data 
   double   fLR[1];
   if(CopyBuffer(fastLRHandle,0,0,1,fLR)!=1)
     {
      Print("CopyBuffer from LRmt failed, no data");
      return;
     }
     
//--- check signals
   ENUM_ORDER_TYPE signal=WRONG_VALUE;

   if(rt[0].open>fLR[0] && rt[0].close<fLR[0]) signal=ORDER_TYPE_SELL;    // sell conditions
   else {
      if(rt[0].open<fLR[0] && rt[0].close>fLR[0]) signal=ORDER_TYPE_BUY;  // buy conditions
      }
//--- additional checking
   if(signal!=WRONG_VALUE) {
      
      double MAT1[1],MAT2[1],LRT1[1],LRT2[1],kMA,nMA,kLR,nLR;
      
      if(CopyBuffer(MATunnel1Handle,0,0,1,MAT1)!=1)
     {
      Print("CopyBuffer from MAT1 failed, no data");
      return;
     }
     
   if(CopyBuffer(MATunnel2Handle,0,0,1,MAT2)!=1)
     {
      Print("CopyBuffer from MAT2 failed, no data");
      return;
     }
     
   if(CopyBuffer(LRTunnel1Handle,0,0,1,LRT1)!=1)
     {
      Print("CopyBuffer from LRT1 failed, no data");
      return;
     }
     
   if(CopyBuffer(LRTunnel2Handle,0,0,1,LRT2)!=1)
     {
      Print("CopyBuffer from LRT2 failed, no data");
      return;
     }
     
   //--- checking tunnel wall positions
   
   if(MAT1[0]<MAT2[0]) { kMA=MAT1[0]; nMA=MAT2[0]; }
   else { kMA=MAT2[0]; nMA=MAT1[0]; }
   
   if(LRT1[0]<LRT2[0]) { kLR=LRT1[0]; nLR=LRT2[0]; }
   else { kLR=LRT2[0]; nLR=LRT1[0]; }

/*                
         if(signal==ORDER_TYPE_BUY) {
            if(fLR[0]>MAT1[0] || fLR[0]>MAT2[0] || fLR[0]>LRT1[0] || fLR[0]>LRT2[0] || LRT1[0]>LRT2[0] || LRT1[0]>MAT1[0] || LRT1[0]>MAT2[0] || LRT2[0]>MAT1[0] || LRT2[0]>MAT2[0]) signal=WRONG_VALUE;
            }
         else {
            if(fLR[0]<MAT1[0] || fLR[0]<MAT2[0] || fLR[0]<LRT1[0] || fLR[0]<LRT2[0] || LRT1[0]<LRT2[0] || LRT1[0]<MAT1[0] || LRT1[0]<MAT2[0] || LRT2[0]<MAT1[0] || LRT2[0]<MAT2[0]) signal=WRONG_VALUE;   
            }
*/            
         if(signal==ORDER_TYPE_BUY) {
            if(fLR[0]>kMA || fLR[0]>kLR || LRT1[0]>LRT2[0] || nLR>kMA) signal=WRONG_VALUE;
            }
         else {
            if(fLR[0]<nMA || fLR[0]<nLR || LRT1[0]<LRT2[0] || kLR<nMA) signal=WRONG_VALUE;   
            }
            
                          
         if(signal!=WRONG_VALUE)
            if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
               if(Bars(_Symbol,_Period)>100)
                 {
                  CTrade trade;
                  trade.PositionOpen(_Symbol,signal,TradeSizeOptimized(),
                                     SymbolInfoDouble(_Symbol,signal==ORDER_TYPE_SELL ? SYMBOL_BID:SYMBOL_ASK),
                                     0,0);
                                  
                }
     }
//---
  }
//+------------------------------------------------------------------+
//| Check for close position conditions                              |
//+------------------------------------------------------------------+
void CheckForClose()
  {
   MqlRates rt[2];
//--- go trading only for first ticks of new bar
   if(CopyRates(_Symbol,_Period,0,2,rt)!=2)
     {
      Print("CopyRates of ",_Symbol," failed, no history");
      return;
     }

   if(rt[1].tick_volume>1) return;
//--- get current Moving Average 
   double   fLR[1],MAT1[1],MAT2[1],LRT1[1],LRT2[1],kMA,nMA,kLR,nLR;
   
   if(CopyBuffer(fastLRHandle,0,0,1,fLR)!=1)
     {
      Print("CopyBuffer from LRmt failed, no data");
      return;
     }
     
   if(CopyBuffer(MATunnel1Handle,0,0,1,MAT1)!=1)
     {
      Print("CopyBuffer from MAT1 failed, no data");
      return;
     }
     
   if(CopyBuffer(MATunnel2Handle,0,0,1,MAT2)!=1)
     {
      Print("CopyBuffer from MAT2 failed, no data");
      return;
     }
     
   if(CopyBuffer(LRTunnel1Handle,0,0,1,LRT1)!=1)
     {
      Print("CopyBuffer from LRT1 failed, no data");
      return;
     }
     
   if(CopyBuffer(LRTunnel2Handle,0,0,1,LRT2)!=1)
     {
      Print("CopyBuffer from LRT2 failed, no data");
      return;
     }
     
//--- positions already selected before
   bool signal=false;
   long type=PositionGetInteger(POSITION_TYPE);
   double twall;

  
   if(MAT1[0]<MAT2[0]) { kMA=MAT1[0]; nMA=MAT2[0]; }
   else { kMA=MAT2[0]; nMA=MAT1[0]; }
   
   if(LRT1[0]<LRT2[0]) { kLR=LRT1[0]; nLR=LRT2[0]; }
   else { kLR=LRT2[0]; nLR=LRT1[0]; }
   
   CTrade trade;
   
   if(type==(long)POSITION_TYPE_BUY) {
   
   if(rt[0].open<nMA && rt[0].close>nMA) GlobalVariableSet("TWall",nMA);
   twall=GlobalVariableGet("TWall");
   printf("Distance from Wall = %f",PositionGetDouble(POSITION_PRICE_CURRENT)-twall);
   
/* PROBLEM

   1. A TWall értéke megváltozik, újboli MA átkelés esetén.
   2. A SL is változik az árfolyam megfordulásával, illetve minden tick-nél módosítani akar.
   
*/
 
      if(rt[0].open<nMA){
         if(fLR[0]<kLR){
            if(rt[0].open>fLR[0] && rt[0].close<fLR[0]){
               signal=true;
              }
            }  
         else
           {
            if(rt[0].open>kLR && rt[0].close<kLR){
               signal=true;
            }
           }
         }
      else {
              if(rt[0].open>=twall+0.0377)
                {
                 signal=true;
                }
              else if(rt[0].open>=twall+0.0233)
                     {
                      trade.PositionModify(_Symbol,twall+0.0144,0);
                     }
                   else if(rt[0].open>=twall+0.0144)
                          {
                           trade.PositionModify(_Symbol,twall+0.0089,0);
                          }
                         else if(rt[0].open>=twall+0.0089)
                              {
                               trade.PositionModify(_Symbol,twall+0.0055,0);
                              }
                              else
                                {
                                  if(rt[0].open>nMA && rt[0].close<nMA) {
                                     signal=true;
                                    }
                                 }
         }
     } 
      
   if(type==(long)POSITION_TYPE_SELL) {
   
   if(rt[0].open>kMA && rt[0].close<kMA) GlobalVariableSet("TWall",kMA);
   twall=GlobalVariableGet("TWall");
   printf("Distance from Wall = %f",twall-PositionGetDouble(POSITION_PRICE_CURRENT));
   
      if(rt[0].open>kMA){
         if(fLR[0]>nLR){
            if(rt[0].open<fLR[0] && rt[0].close>fLR[0]){
               signal=true;
              }
            }  
         else
           {
            if(rt[0].open<nLR && rt[0].close>nLR){
               signal=true;
            }
           }
         }
      else {
              if(rt[0].open<=twall-0.0377)
                {
                 signal=true;
                }
              else if(rt[0].open<=twall-0.0233)
                     {
                      trade.PositionModify(_Symbol,twall-0.0144,0);
                     }
                   else if(rt[0].open<=twall-0.0144)
                           {
                            trade.PositionModify(_Symbol,twall-0.0089,0);
                           }
                         else if(rt[0].open<=twall-0.0089)
                                 {
                                  trade.PositionModify(_Symbol,twall-0.0055,0);
                                 }
                              else
                                {
                                  if(rt[0].open<kMA && rt[0].close>kMA) {
                                     signal=true;
                                  }
                                 }
            
         }
      }
      
//--- additional checking
   if(signal)
      if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
         if(Bars(_Symbol,_Period)>100)
           {
            trade.PositionClose(_Symbol,3);
           }
//---
  }
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   fastLRHandle=iCustom(_Symbol,_Period,"Linear_Regression_Moving_Totals",fastLRPeriod);
   LRTunnel1Handle=iCustom(_Symbol,_Period,"Linear_Regression_Moving_Totals",LRTunnel1);
   LRTunnel2Handle=iCustom(_Symbol,_Period,"Linear_Regression_Moving_Totals",LRTunnel2);
   MATunnel1Handle=iMA(_Symbol,_Period,MATunnel1,0,MODE_EMA,PRICE_CLOSE);
   MATunnel2Handle=iMA(_Symbol,_Period,MATunnel2,0,MODE_EMA,PRICE_CLOSE);
   
   if(fastLRHandle==INVALID_HANDLE || LRTunnel1Handle==INVALID_HANDLE || LRTunnel2Handle==INVALID_HANDLE || MATunnel1Handle==INVALID_HANDLE || MATunnel2Handle==INVALID_HANDLE)
     {
      printf("Error creating LR indicators");
      return(-1);
     }
   
   ChartIndicatorAdd(0,0,fastLRHandle);
   ChartIndicatorAdd(0,0,LRTunnel1Handle);
   ChartIndicatorAdd(0,0,LRTunnel2Handle);
   ChartIndicatorAdd(0,0,MATunnel1Handle);
   ChartIndicatorAdd(0,0,MATunnel2Handle);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   if(PositionSelect(_Symbol)) CheckForClose();
   else                        CheckForOpen();
//---
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
