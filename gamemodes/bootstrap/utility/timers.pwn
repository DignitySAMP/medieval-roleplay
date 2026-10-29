#define Timer_Declare(%0) const %0@timer_declared = 1; forward %0(); public %0()
#define Timer_DeclareEx(%0,%1) const %0@timer_declared = 1; forward %0(%1); public %0(%1)
#define Timer_Start(%0,%1) (%0@timer_declared ? SetTimer(#%0,(%1),true) : -1)
#define Timer_StartEx(%0,%1,%2,%3) (%0@timer_declared ? SetTimerEx(#%0,(%1),true,%2,%3) : -1)
