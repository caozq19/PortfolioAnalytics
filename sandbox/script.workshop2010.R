### For R/Finance workshop on Portfolio Analytics
# Chicago, 16 April 2010
# Peter Carl and Brian Peterson

### Load the necessary packages
# Include optimizer and multi-core packages
library(PortfolioAnalytics)
require(xts)
require(DEoptim)
require(doMC)
registerDoMC()
require(TTR)

### Load the data
# Monthly total returns of four asset-class indexes
data(indexes)
#only look at 2000 onward
indexes<-indexes["2000::"]

#'## Review the data
postscript(file="WeightsVsRiskReview.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
# Generate charts to show 12m sma returns and CVaR by asset
charts.BarVaR(indexes[,1:4], p=(1-1/12), clean='boudt', show.cleaned=TRUE, methods=c("ModifiedVaR","ModifiedES"), colorset=rainbow6equal, cex.axis=1)
# Weights v %Contrib to CVaR
table = as.matrix(ES(indexes[,1:4], weights=rep(1/4,4), portfolio_method="component", p=(1-1/12))$pct_contrib_MES)
table = cbind(rep(1/4,4),table)
colnames(table) = c("Weights", "%Contrib to CVaR")
plot(table, ylim=c(-0.1,1), xlim=c(0,1), col=1:4, main="Weight and Contribution to Risk")
text(table[,1],table[,2],rownames(table), pos=4, cex = 0.8, col=1:4)
abline(a=0,b=1, col="darkgray", lty="dotted")
dev.off()

### Create a benchmark using equal-weighted portfolio returns
# Rebalance an equal-weight portfolio quarterly
dates=c(as.Date("1999-12-31"),time(indexes[endpoints(indexes, on="quarters")]))
weights = xts(matrix(rep(1/4,length(dates)*4), ncol=4), order.by=dates)
colnames(weights)= colnames(indexes[,1:4])
EqWgt = Return.rebalancing(indexes[,1:4],weights)

# Chart EqWgt Results
postscript(file="EqWgtPlot1.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.PerformanceSummary(EqWgt, main="Eq Wgt Portfolio", methods=c("ModifiedVaR", "ModifiedES"), p=(1-1/12), clean='boudt', show.cleaned=TRUE, gap=36, colorset=bluefocus, lwd=3)
dev.off()

### Chart the VaR Sensitivity
postscript(file="VaRSense.eps", height=6, width=6, paper="special", horizontal=FALSE, onefile=FALSE)
layout(matrix(c(1,2,3,4), nrow=2))
for(i in 1:4)
  chart.VaRSensitivity(indexes[,i], methods=c("ModifiedES", "HistoricalES", "GaussianES"), colorset=bluemono, lwd=c(3,2,2), clean="boudt", main=paste("VaR Sensitivity for", colnames(indexes)[i], sep=" "), cex=.8)
dev.off()

# chart the assets
postscript(file="assetReturns.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.BarVaR(indexes[,1:4], methods=c("ModifiedVaR", "ModifiedES"), colorset=rep("black",4), clean="boudt", show.clean=TRUE)
dev.off()

#'# EXAMPLE 1: Constrained Mean-CVaR Portfolio
### Show an example of a constraint set
aConstraintObj <- constraint(assets = colnames(indexes[,1:4]),
min = .05, # minimum position weight
max = c(.85,.5,.5,.3), #1, # maximum position weight
min_sum=0.99, # minimum sum of weights must be equal to 1-ish
max_sum=1.01, # maximum sum must also be about 1
weight_seq = generatesequence()) # possible weights for random or brute force portfolios

### Add a return objective to a constraint
# Create a small weighted annualized trailing-period mean wrapper function
pamean <- function(n=12, R, weights, geometric=TRUE)
{ sum(Return.annualized(last(R,n), geometric=geometric)*weights) }

# Portfolio annualized exponential moving average monthly return
aConstraintObj <- add.objective(constraints=aConstraintObj,
type="return",
name="pamean",
enabled=TRUE,
multiplier=-1, # to maximize this objective using a minimizer
arguments = list(n=12))

### Add a risk objective to a constraint
aConstraintObj <- add.objective(aConstraintObj,
type="risk", # the kind of objective this is
name="CVaR", # the function to minimize
enabled=TRUE, # enable or disable the objective
arguments=list(p=(1-1/12), clean="boudt")
)

### Use the Random Portfolios engine
# Evaluate the constraint object with Random Portfolios
rndResult<-optimize.portfolio(R=indexes[,1:4],
constraints=aConstraintObj,
optimize_method='random',
search_size=1000, trace=TRUE, verbose=TRUE)

# Chart the results
postscript(file="rpPerformancePlot1.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.RP(rndResult, risk.col="CVaR", return.col="pamean", main="Constrained Mean-CVaR", neighbors=25)
dev.off()

# Chart the weights versus contribution to risk
postscript(file="WeightsVsRisk1.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
table = ES(indexes[,1:4],weights=rndResult$weights, portfolio_method="component", p=(1-1/12))$pct_contrib_MES
table = cbind(rndResult$weights,table)
colnames(table) = c("Weights", "%Contrib to CVaR")
plot(table, ylim=c(0,1), xlim=c(0,1), col=rainbow6equal, main="Weight and Contribution to Risk")
text(table[,1],table[,2],rownames(table), pos=4, cex = 1, col=rainbow6equal)
abline(a=0,b=1, col="darkgray", lty="dotted")
dev.off()

## Evaluate Constrained Mean-CVaR through time
#on one line for easy cut/paste/editing in interactive mode
registerDoMC()
rndResults<-optimize.portfolio.rebalancing(R=indexes[,1:4], constraints=aConstraintObj, optimize_method="random", trace=TRUE, rebalance_on='quarters', trailing_periods=NULL, training_period=36, search_size=1000)

# Chart the cumulative returns
weights1=extractWeights.rebal(rndResults)
Ex1=Return.rebalancing(indexes[,1:4], weights1)
index(weights1)<-as.Date(index(weights1))+1
colnames(Ex1)="Mean CVaR"
results = cbind(EqWgt,Ex1)
postscript(file="ReturnsEx1.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.PerformanceSummary(results[,2:1], main="Constrained Mean-CVaR", colorset=bluefocus[-3], lwd=c(3,2), method=c("ModifiedVaR","ModifiedES"), p=(1-1/12), gap=36)
dev.off()

# Chart the weights and contribution to risk through time
# First, extract weights and calculate ES
numColumns = length(rndResults[[1]]$weights)
numRows = length(rndResults)
contrib1 <- matrix(nrow=numRows, ncol=numColumns)
for(i in 1:numRows){
    todate=paste("::",as.Date(names(rndResults)[i]), sep="")
    contrib1[i,]=ES(indexes[todate,1:4], portfolio_method="component", weights=rndResults[[i]]$weights, clean="boudt", p=(1-1/12))$pct_contrib_MES
}
colnames(contrib1) = names(unlist(rndResults[[1]]$weights))
contrib1<-xts(contrib1,order.by=index(weights1))

# test
postscript(file="InSampleStats.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)

  retrisk1 <- matrix(nrow=numRows, ncol=2)
  for(i in 1:numRows)
    retrisk1[i,] = unlist(rndResults[[i]]$objective_measures)
  rownames(retrisk1) = names(rndResults)
  colnames(retrisk1) = c("pamean", "CVaR")
 chart.TimeSeries(retrisk1, legend="topright", main="In Sample Estimates")
dev.off()
# end test

postscript(file="WeightsContribEx1.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
layout(rbind(1, 2, 3), height = c(3, 3, 1.2), width = 1)
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(weights1, main="Mean-CVaR Weights", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(contrib1, main="Mean-CVaR Risk Contribution", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
plot.new()
par(oma = c(0, 0, 0, 0), mar=c(2,4,4,2)) #c(bottom, left, top, right)
legend("top", legend = colnames(weights1), fill = bluemono[c(-2,-4,-6)], ncol = 4, box.col="darkgray", border.col="white", cex=1)
dev.off()

#'# EXAMPLE 2: Mean-CVaR Risk Limit Portfolio
### Add a risk contribution constraint
# No more than 40% of the risk may be contributed by any one asset
# Reset the position constraints
aConstraintObj$max <-rep(1,4)
names(aConstraintObj$max) <- names(aConstraintObj$min)

aConstraintObj <- add.objective(aConstraintObj, type="risk_budget", name="CVaR",  enabled=TRUE, min_prisk=-Inf, max_prisk=.4, arguments = list(clean='boudt', method="modified",p=(1-1/12)))

rndResult2<-optimize.portfolio(R=indexes[,1:4],
constraints=aConstraintObj,
optimize_method='random',
search_size=1000, trace=TRUE, verbose=TRUE)

### Chart the results
postscript(file="rpPerformancePlot2.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.RP(rndResult2, risk.col="CVaR", return.col="pamean", main="Mean-CVaR With Risk Limits", neighbors=25)
dev.off()

# Chart the weights versus contribution to risk
postscript(file="WeightsVsRisk2.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
table = cbind(rndResult2$weights, rndResult2$objective_measures$CVaR$pct_contrib_MES)
colnames(table) = c("Weights", "%Contrib to CVaR")
plot(table, ylim=c(0,1), xlim=c(0,1), col=rainbow6equal, main="Weight and Contribution to Risk")
text(table[,1],table[,2],rownames(table), pos=4, cex = 1, col=rainbow6equal)
abline(a=0,b=1, col="darkgray", lty="dotted")
dev.off()

### Evaluate Mean-CVaR Risk Limit through time
#on one line for easy cut/paste/editing in interactive mode
registerDoMC()
rndResults2<-optimize.portfolio.rebalancing(R=indexes[,1:4], constraints=aConstraintObj, optimize_method="random", trace=TRUE, rebalance_on='quarters', trailing_periods=NULL, training_period=36, search_size=3000)

### Chart the results
# Chart the cumulative returns
weights2=extractWeights.rebal(rndResults2)
Ex2=Return.rebalancing(indexes[,1:4], weights2)
index(weights2)<-as.Date(index(weights2)) + 1
colnames(Ex2) = "Risk Limit"
results = cbind(results, Ex2) 
postscript(file="ReturnsEx2.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.PerformanceSummary(results[,3:1], main="Mean-CVaR Risk Limit", colorset=bluefocus[-3], lwd=c(3,2,2), method=c("ModifiedVaR","ModifiedES"), p=(1-1/12), gap=36)
dev.off()

# Chart the weights and contribution to risk through time
numColumns = length(rndResults2[[1]]$weights)
numRows = length(rndResults2)
contrib2 <- matrix(nrow=numRows, ncol=numColumns)
for(i in 1:numRows)
  contrib2[i,] = unlist(rndResults2[[i]]$objective_measures$CVaR$pct_contrib_MES)
colnames(contrib2) = names(unlist(rndResults2[[1]]$objective_measures$CVaR$pct_contrib_MES))
contrib2<-xts(contrib2,order.by=index(weights1))

# op <- par(no.readonly = TRUE)
postscript(file="WeightsContribEx2.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
layout(rbind(1, 2, 3), height = c(3, 3, 1.2), width = 1)
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(weights2, main="Risk Limit Weights", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(contrib2, main="Risk Limit Risk Contribution", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
plot.new()
par(oma = c(0, 0, 0, 0), mar=c(2,4,4,2))
legend("top", legend = colnames(weights2), fill = bluemono[c(-2,-4,-6)], ncol = 4, box.col="darkgray", border.col="white", cex=1)
dev.off()
# par(op)

#'# EXAMPLE 3: Equal Risk Portfolio
### Constraints for an Equal risk contribution portfolio
EqRiskConstr <- constraint(assets = colnames(indexes[,1:4]), min = 0.05, max = c(0.85,0.5,0.5,0.3), min_sum=1, max_sum=1, weight_seq = generatesequence())
EqRiskConstr <- add.objective(EqRiskConstr, type="risk_budget", name="CVaR",  enabled=TRUE, min_concentration=TRUE, arguments = list(clean='boudt', p=(1-1/12)))
EqRiskConstr <- add.objective(constraints=EqRiskConstr, type="return", name="pamean", enabled=TRUE, multiplier=0, arguments = list(n=12))

### Use DEoptim engine
EqRiskResultDE<-optimize.portfolio(R=indexes[,1:4], constraints=EqRiskConstr, optimize_method='DEoptim', search_size=2000, trace=TRUE, verbose=FALSE) #itermax=55, CR=0.99, F=0.5,

postscript(file="EqRiskDE.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.DE(EqRiskResultDE, return.col="pamean", risk.col="CVaR")
dev.off()

### Evaluate through time
EqRiskResultDERebal<-optimize.portfolio.rebalancing(R=indexes[,1:4],
constraints=EqRiskConstr, optimize_method="DEoptim", trace=FALSE, rebalance_on='quarters', trailing_periods=NULL, training_period=36, itermax=75, CR=0.99, F=0.5, search_size=3000)

### Chart results
# Panel 1: Equal Risk Performance Summary
EqRiskWeights=extractWeights.rebal(EqRiskResultDERebal)
EqRisk=Return.rebalancing(indexes, EqRiskWeights)
index(EqRiskWeights)<-as.Date(index(EqRiskWeights)) + 1
R=cbind(EqRisk,EqWgt)
colnames(R)=c("Equal Risk","Equal Weight")
postscript(file="EqRiskPerf.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.PerformanceSummary(R, methods=c("ModifiedVaR", "HistoricalVaR"), p=(1-1/12), colorset=bluefocus)
dev.off()

# Panel 2: Equal Risk Allocations
postscript(file="EqRiskBars.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
layout(rbind(1, 2, 3), height = c(3, 3, 1.2), width = 1)
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(EqRiskWeights, main="Equal Risk Weights", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
par(mar = c(2, 4, 4, 2) + 0.1)
### @TODO: Make this an extract function or calculate in the optim results
EqRiskPercContrCVaR=matrix(nrow=nrow(EqRiskWeights), ncol=ncol(EqRiskWeights))
for(i in 1:nrow(EqRiskWeights)){
    dates = paste(index(indexes)[1], index(EqRiskWeights)[i], sep="::")
    EqRiskPercContrCVaR[i,] = ES(indexes[dates,1:4], weights=EqRiskWeights[i,], p=(1-1/12), portfolio_method="component")$pct_contrib_MES
}
colnames(EqRiskPercContrCVaR) = names(EqRiskResultDERebal[[1]]$weights)
EqRiskPercContrCVaR<-xts(EqRiskPercContrCVaR,order.by=index(weights1))
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(EqRiskPercContrCVaR, main="Equal Risk Risk Contribution", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
plot.new()
par(oma = c(0, 0, 0, 0), mar=c(2,4,4,2))
legend("top", legend = colnames(weights1), fill = bluemono[c(-2,-4,-6)], ncol = 4, box.col="darkgray", border.col="white", cex=1)
dev.off()

#'## extended Equal Risk example
#' shart with the prior example
CDDConstr<-EqRiskConstr
#' turn back on the return objective
CDDConstr$objectives[[2]]$multiplier = -1
#' turn off risk_budget objective
CDDConstr$objectives[[1]]$multiplier = 0
#' add CDD objective
CDDConstr <- add.objective(CDDConstr, type="risk", name="CDD",  enabled=TRUE, arguments = list(p=(1-1/12)))

### Use DEoptim engine
CDDResultDE2<-optimize.portfolio(R=indexes[,1:4], constraints=CDDConstr, optimize_method='DEoptim', search_size=3000, trace=TRUE, verbose=FALSE, itermax=75, CR=0.99, F=0.5)
postscript(file="CDDDE2.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.DE(CDDResultDE2, return.col="pamean", risk.col="CDD")
dev.off()

### Evaluate through time
CDDResultDERebal2<-optimize.portfolio.rebalancing(R=indexes[,1:4],
        constraints=CDDConstr, optimize_method="DEoptim", trace=FALSE, rebalance_on='quarters', trailing_periods=NULL, training_period=36, itermax=75, CR=0.99, F=0.5, search_size=3000)

### Chart results
# Panel 1: CDD Performance Summary
CDDweights=extractWeights.rebal(CDDResultDERebal2)
CDDRet=Return.rebalancing(indexes, CDDweights)
index(CDDweights)<-as.Date(index(CDDweights)) + 1
R=cbind(CDDRet,EqWgt)
colnames(R)=c("CDD","Equal Weight")
postscript(file="CDDPerf.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.PerformanceSummary(R, methods=c("ModifiedVaR", "HistoricalVaR"), p=(1-1/12), colorset=bluefocus)
dev.off()

# Panel 2: CDD Allocations
postscript(file="CDDBars2.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
layout(rbind(1, 2, 3), height = c(3, 3, 1.2), width = 1)
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(CDDweights, main="CDD w/ Return Obj. Weights", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
par(mar = c(2, 4, 4, 2) + 0.1)
### @TODO: Make this an extract function or calculate in the optim results
CDDPercContrCVaR2=matrix(nrow=nrow(CDDweights), ncol=ncol(CDDweights))
for(i in 1:nrow(CDDweights)){
    dates = paste(index(indexes)[1], index(CDDweights)[i], sep="::")
    CDDPercContrCVaR2[i,] = ES(indexes[dates,1:4], weights=CDDweights[i,], p=(1-1/12), portfolio_method="component")$pct_contrib_MES
}
colnames(CDDPercContrCVaR2) = names(unlist(CDDResultDERebal2[[1]]$weights))
CDDPercContrCVaR2<-xts(CDDPercContrCVaR2,order.by=index(weights1))
par(mar = c(2, 4, 4, 2) + 0.1)
PerformanceAnalytics:::chart.StackedBar.xts(CDDPercContrCVaR2, main="CDD w/ Ret. Obj. Risk Contribution", legend.loc=NULL, cex.axis=1, colorset=bluemono[c(-2,-4,-6)], space=0, border="darkgray")
plot.new()
par(oma = c(0, 0, 0, 0), mar=c(2,4,4,2))
legend("top", legend = colnames(weights1), fill = bluemono[c(-2,-4,-6)], ncol = 4, box.col="darkgray", border.col="white", cex=1)
dev.off()



#'## APPENDIX EXAMPLES? ###
stopifnot(isTRUE(extended_ex),"halting")

## Markowitz-like constrained mean-variance
MeanVarConstr <- constraint(assets = colnames(indexes[,1:4]),
min = 0, max = 1, min_sum=0.99, max_sum=1.01, 
weight_seq = generatesequence())

MeanVarConstr <- add.objective(constraints=MeanVarConstr, type="return", name="mean", enabled=TRUE, multiplier=-1, arguments = list())

MeanVarConstr <- add.objective(MeanVarConstr,
type="risk", # the kind of objective this is
name="sd",
enabled=TRUE, # enable or disable the objective
arguments= list())

MeanVarResultRP<-optimize.portfolio(R=indexes[,1:4],
constraints=MeanVarConstr,
optimize_method='random',
search_size=1000,
trace=TRUE, verbose=TRUE)
# Chart the results
postscript(file="mvRP.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
charts.RP(MeanVarResultRP, risk.col="sd", return.col="mean", main="Mean Variance", neighbors=25)
dev.off()

MeanVarResultRPRebal<-optimize.portfolio.rebalancing(R=indexes[,1:4],
constraints=MeanVarConstr, 
optimize_method="random",
trace=FALSE, 
rebalance_on='quarters', 
trailing_periods=NULL, 
training_period=36, 
search_size=1000)

## Risk budget
RiskBudget.constr <- constraint(assets = colnames(indexes[,1:4]), min = 0, max = 1, min_sum=1, max_sum=1, weight_seq = generatesequence())

RiskBudget.constr <- add.objective(RiskBudget.constr, type="risk_budget", name="CVaR",  enabled=TRUE, min_prisk=-Inf, max_prisk=.4, arguments = list(clean='boudt', method="modified",p=.95))

RiskBudget.constr <- add.objective(constraints=RiskBudget.constr, type="risk", name="CVaR", enabled=TRUE, arguments = list(method="modified", portfolio_method="single", enabled=TRUE, p=.95, clean="boudt"))

RiskBudget.optimResult<-optimize.portfolio(R=indexes[,1:4], constraints=RiskBudget.constr,
optimize_method='DEoptim', search_size=1000, verbose=TRUE)

## Equal risk
# First method: minimize risk concentration across assets
EqRiskConstr1 <- constraint(assets = colnames(indexes[,1:4]), min = 0.05, max = c(0.85,0.5,0.5,0.3), min_sum=0.99, max_sum=1.01, weight_seq = generatesequence())
EqRiskConstr1 <- add.objective(EqRiskConstr1, type="risk_budget", name="CVaR",  enabled=TRUE, min_concentration=TRUE, arguments = list(clean='boudt', p=(1-1/12)))
EqRiskResultDE1<-optimize.portfolio(R=indexes[,1:4], constraints=EqRiskConstr1, optimize_method='DEoptim', search_size=2000, trace=TRUE, verbose=FALSE) #itermax=55, CR=0.99, F=0.5,

# Second method: force risk levels between limits
EqRiskConstr <- constraint(assets = colnames(indexes[,1:4]), min = 0.05, max = c(0.85,0.5,0.5,0.3), min_sum=1, max_sum=1, weight_seq = generatesequence())
EqRiskConstr <- add.objective(EqRiskConstr, type="risk_budget", name="CVaR", enabled=TRUE, arguments = list(p=(1-1/12), clean="boudt"), min_prisk=0.24, max_prisk=0.26)
EqRiskResultDE<-optimize.portfolio(R=indexes[,1:4], constraints=EqRiskConstr, optimize_method='DEoptim', search_size=2000, trace=TRUE, verbose=FALSE)

#EqRiskResultRP<-optimize.portfolio(R=indexes[,1:4], constraints=EqRiskConstr, optimize_method='random', search_size=1000, trace=TRUE, verbose=TRUE)
# Chart the results
# postscript(file="EqRiskRP.eps", height=6, width=5, paper="special", horizontal=FALSE, onefile=FALSE)
# charts.RP(EqRiskResultRP, risk.col="CVaR", return.col="mean", main="Mean Variance", neighbors=25)
# dev.off()
EqRiskResultDERebal<-optimize.portfolio.rebalancing(R=indexes[,1:4],
constraints=EqRiskConstr, optimize_method="DEoptim", trace=FALSE, rebalance_on='quarters', trailing_periods=NULL, training_period=36, itermax=45, CR=0.99, F=0.5, search_size=1000)

# Panel 1: Equal Risk Performance Summary
EqRiskWeights=extractWeights.rebal(EqRiskResultDERebal)
EqRisk=Return.rebalancing(indexes, EqRiskWeights)
index(EqRiskWeights)<-as.Date(index(EqRiskWeights)) + 1
R=cbind(EqRisk,EqWgt)
colnames(R)=c("Equal Risk","Equal Weight")
charts.PerformanceSummary(R, methods=c("ModifiedVaR", "HistoricalVaR"), p=(1-1/12), colorset=redfocus)

# Panel 2: Equal Risk Allocations
chart.StackedBar(EqRiskWeights)
## @TODO: Make this an extract function or calculate in the optim results
EqRiskPercContrCVaR=matrix(nrow=nrow(EqRiskWeights), ncol=ncol(EqRiskWeights))
for(i in 1:nrow(EqRiskWeights)){
    dates = paste(index(indexes)[1], index(EqRiskWeights)[i], sep="::")
    EqRiskPercContrCVaR[i,] = ES(indexes[dates,1:4], weights=EqRiskWeights[i,], p=(1-1/12), portfolio_method="component")$pct_contrib_MES
}
colnames(EqRiskPercContrCVaR) = names(unlist(EqRiskResultDERebal[[1]]$weights))
rownames(EqRiskPercContrCVaR) = colnames(weights1)
chart.StackedBar(EqRiskPercContrCVaR)

## Return target with risk budget

## You want to do what?


### ---------------------- Scratch area ---------------------- ###
# Single period DEOptim results
assets.pema=matrix(nrow=1,ncol=4)
# for(i in 1:4){ assets.pema[,i] = paEMA(n=12,indexes[,i],1) }
for(i in 1:4){ assets.pema[,i] = Return.annualized(last(indexes[,i],12),geometric=TRUE) }
colnames(assets.pema)=colnames(indexes[,1:4])
rownames(assets.pema)="Tr 12m Ann Return"
assets.CVaR=ES(indexes[,1:4], invert=FALSE)
assets = rbind(assets.CVaR,assets.pema)
pdf()
plot(t(assets))
points(optimResult$objective_measures[1], optimResult$objective_measures[2])
text(t(assets), colnames(assets))
text(optimResult$objective_measures[1], optimResult$objective_measures[2], "Optimal")
dev.off()
paEMA <- function(n=10, R, weights, ...)
{# call Exponential Moving Average from TTR, return the last observation
    sum((12*last(apply(R,2,FUN=TTR::EMA,n=n)))*weights)
}
#     xtract = extractStats.rp(rndResult)
#     plot(xtract[,6],xtract[,7], xlab="CVaR", ylab="pEMA", col="lightgray", main="Random Portfolios")
#     points(xtract[1,6],xtract[1,7], col="orange", pch=16) # equal weighted (seed)
#     points(rndResult$constrained_objective[[1]], rndResult$constrained_objective[[2]], col="red", pch=16)

## Use DEoptim as an engine
optimResult<-optimize.portfolio(R=indexes[,1:4],
constraints=aConstraintObj,
optimize_method='DEoptim',
itermax=45, CR=0.99, F=0.5,
search_size=2000 #, verbose=TRUE
)

### Run it several times
optimResultList <- foreach(ii=iter(1:20),# find 20 sol'ns
.errorhandling='pass') %dopar%
optimize.portfolio(R=indexes[,1:4], aConstraintObj,
optimize_method='DEoptim', trace=TRUE,
itermax=25, CR=0.99, F=0.5, search_size=1000)

rndResultList <- foreach(ii=iter(1:20),# 120 sol'ns
.errorhandling='pass') %dopar%
optimize.portfolio(R=indexes[,1:4], aConstraintObj,
optimize_method='random', trace=TRUE,
search_size=1000, verbose=TRUE)

### Evaluate through time
#on one line for easy cut/paste/editing in interactive mode
registerDoMC()
rndResults<-optimize.portfolio.rebalancing(R=indexes[,1:4], constraints=aConstraintObj, optimize_method="random", trace=TRUE, rebalance_on='quarters', trailing_periods=NULL, training_period=36, search_size=1000)

# on multiple, for demo
rndResults<-optimize.portfolio.rebalancing(R=indexes[,1:4],
constraints=aConstraintObj, # our constraints object
optimize_method="random", # allows kitchen sink sol'ns
trace=FALSE, # set verbosity for tracking
rebalance_on='quarters', # any xts 'endpoints'
trailing_periods=NULL, # calculation from inception
training_period=36, # starting period for calculation
search_size=1000) # how many portfolios to test
