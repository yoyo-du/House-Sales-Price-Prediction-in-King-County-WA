*read the dataset;
libname project '/folders/myfolders/project';

proc import datafile='/folders/myfolders/project/kc_house_data.csv'
	out=project.price
	dbms=csv
	replace;
	getnames=yes;
run;

*see the details about the variables;
proc contents data=project.price varnum;
run;


*transfer the date and zipcode format to numeric;
data new_date;
  set project.price (rename=(date=char_date));
  date = substr(char_date, 1, 8);
  drop char_date;
run;


*check the house with 33 bedrooms;
data observation;
set project.price;
where bedrooms=33;
run;

data project.new_price;
  set new_date (rename=(date=char_date
                        zipcode=char_zipcode
                        floors=char_floors));
  date = input(char_date, yymmdd10.);
  zipcode = input(char_zipcode, 5.);
  year = year(date);
  if yr_renovated > 0 then years = year - yr_renovated;
  else years = year - yr_built;
  floors = input(char_floors, 5.);
  if bedrooms < 33;
  *month = Month(date);
  log_price = log(price);
  format date yymmdd10.;
  drop char_date char_zipcode char_floors id;
run;

proc means data = project.new_price nmiss mean median min max maxdec=1;run; 

	
proc sort data = project.new_price out = project.date_order;
by year month;
run;

proc report data = project.new_price nowd out = date;
  column price year month;
  define year / group "Year_order" width = 10;
  define month / group "Month_order" width = 11;
  define price / median "Median Price" width = 10;
run;


proc means data=project.new_price noprint nway;
class zipcode;
var price;
output out=data2 mean=mean_price median = median_price;
run;

proc sort data=data2 out = data3;
by descending median_price;
run;

*zipcode: 98039, 98004, 98040 has the highest median price;  


title 'Median Price by Zipcode';
proc sgplot data=project.new_price;
  vbar zipcode / response=price  
    stat=median dataskin=gloss;
run;
*not a good plot;


*boxplot of number of bedroom, bathrooms, condition;
proc sort data=project.numeric out = condition_sort;
by condition;run;

proc sort data=project.numeric out = grade_sort;
by grade;run;

proc sort data=project.numeric out = waterfront_sort;
by waterfront;run;

proc sgplot data=bedroom_sort;
   vbox log_price / category=bedrooms;
run;

proc sgplot data=project.numeric;
   vbox log_price / category=waterfront;
run;

proc sgplot data=project.numeric;
   vbox log_price / category=grade;
run;

proc sgplot data=project.numeric;
   scatter x= grade y=log_price;
run;


proc boxplot data=condition_sort;
plot log_price*condition / totpanels=1
boxstyle=schematic
notches
idsymbol=dot
cboxes=black
vaxis=axis1;
run;

proc boxplot data=grade_sort;
plot log_price*grade / totpanels=1
boxstyle=schematic
notches
idsymbol=dot
cboxes=black
vaxis=axis1;
run;

proc boxplot data=waterfront_sort;
plot log_price*waterfront / totpanels=1
boxstyle=schematic
notches
idsymbol=dot
cboxes=black
vaxis=axis1;
run;

proc sgplot data=project.new;
   vbar bedrooms;
run;

PROC SGPLOT DATA = project.new_price;
VBAR waterfront;
RUN;

PROC SGPLOT DATA = project.new_price;
VBAR view;
RUN;

PROC SGPLOT DATA = project.new_price;
VBAR grade;
RUN;

PROC SGPLOT DATA = project.new_price;
VBAR years;
RUN;

*plot the daily average house price;
proc sort data=project.new_price out=date_price;
 by date; 
run;

proc summary data=date_price nway;
class date;
var price;
output out=want mean=;
run;

title 'Average Daily House Price';
proc sgplot data=want;
 series x=date y=price;
run;


*plot the yearly average house price based on the year of the house was built;
proc sort data=project out=build_price;
 by yr_built; 
run;

proc summary data=build_price nway;
class yr_built;
var price;
output out=built_price mean=;
run;

proc sgplot data=built_price;
 series x=yr_built y=price;
run;

proc sgplot data=project.new_price;
 scatter x=years y=log_price;
run;

*plot the yearly average house price based on the year of the house was renovated;
proc sort data=project.new_price out=renovate_price;
 by yr_renovated; 
run;

proc summary data=renovate_price nway;
class yr_renovated;
var price;
output out=renovate_price mean=;
run;

proc sgplot data=renovate_price;
 series x=yr_renovated y=price;
run;

proc sgplot data=project.new_price;
 scatter x=years y=log_price;
run;


*plot the yearly average house price based on the years;
proc sort data=project.new_price out=years_price;
 by years; 
run;

proc summary data=years_price nway;
class years;
var log_price;
output out=year_price mean=;
run;

proc sgplot data=year_price;
 series x=years y=log_price;
run;


*Histogram of Price;
proc sgplot data=project.new_price;
 Histogram price;
 Density price;
 Title 'Histogram of House Price';
Run;

*Histogram of logPrice;
proc sgplot data=project.new_price;
 Histogram log_price;
 Density log_price;
 Title 'Histogram of House Price(logarithm)';
Run;

*pretty normal;

proc sgplot data=project.new;
 vbox price;
 Title 'Boxplot of House Price';
Run;



*House Price Map;
proc geocode method=zip
 data=project.new
 ADDRESSZIPVAR=zipcode
 out=geocoded
 nocity
 attributevar=(zipcode price lat long);
run;

%let url = http://services.arcgisonline.com/arcgis/rest/services;                                                                       
                                                                               
title 'House Price Map';
proc sgmap plotdata=geocoded;                                                                                                          
  esrimap url="&url/World_Topo_Map";                                                                                                    
  bubble x=X y=Y size=price;                                                                                                                                                                                                           
run;


*drop some variables;
data project.numeric;
 set project.new_price;
 drop price yr_built yr_renovated sqft_above sqft_basement date year;
run;

*standardize variables first;
PROC STANDARD DATA=project.numeric MEAN=0 STD=1 OUT=znumeric;
  VAR bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long sqft_living15 sqft_lot15 years floors;
RUN;

*one-hot encoding on zipcode;
proc sort data=znumeric;
by zipcode;
run;

 
data list;
set znumeric;
by zipcode;
if first.zipcode then count+1;
run;

*70 unique zipcode values;
data zipcode;
 set list; 
 array dummys {*} count_1-count_70;
 Do i = 1 to 70;
  dummys(i) = 0;
 End;
 dummys(count) = 1;
 drop count years i;
run;

*spilt training and test set;
proc surveyselect data = zipcode out = traintest seed=123
 samprate = 0.7 method = srs outall;
run;

data train test;
 set traintest; 
 if selected =1 then output train; 
 else output test;
run;

*lasso regression;
proc glmselect data = traintest plots=all seed=12345;
  partition ROLE = selected(train='1' test='0');
  model log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long 
  sqft_living15 sqft_lot15 floors count_1-count_70/ selection = lasso(choose=cv stop=none) cvmethod = random(10);
run;




proc corr data=zipcode plots(MAXPOINTS=NONE); *PLOTS=matrix(histogram); 
var sqft_living bathrooms bedrooms grade;
run;



* principle component analysis;
proc princomp data=znumeric out = project.prin_analysis(keep=log_price Prin1-Prin14);
var bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long sqft_living15 sqft_lot15 years floors;
run;

proc princomp data=project.princ;
run;

*multiple linear regression based on principle component analysis; *google how many components should we use;
proc reg data= project.prin_analysis PLOTS(MAXPOINTS=NONE);
 model log_price = Prin1 Prin2 Prin3 Prin4 Prin5 Prin6;
run;
quit;

*multiple linear regression;
proc reg data=znumeric plots(maxpoints=none); 
model log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long sqft_living15 sqft_lot15 years floors / vif; 
run; quit;

proc reg data=znumeric; 
model log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long sqft_living15 sqft_lot15 years floors / selection=stepwise; 
run; quit;



*multiple linear regression: stepwise;
PROC glmselect DATA = traintest PLOTS=all seed=12345; 
 partition ROLE = selected(train='1' test='0');
MODEL log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade 
 lat long sqft_living15 sqft_lot15 years floors  / SELECTION=stepwise;
RUN;

proc reg data=project.znumeric; 
model log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade 
 lat long sqft_living15 years floors / VIF p clm; run; quit;


proc pls data=traintest method=PCR nfac=6;          /* PCR onto 4 factors */
   model log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long sqft_living15 sqft_lot15 years floors / solution;
run;




proc reg data=zipcode; 
model log_price = bedrooms bathrooms sqft_living sqft_lot waterfront view condition grade lat long sqft_living15 sqft_lot15 years floors count_1-count_70 / selection=stepwise; 
run; 
quit;


data drop_1;
 set zipcode (keep=zipcode count_9);
 where count_9 =1;
 output;
run;

data drop_2;
 set zipcode (keep=zipcode count_56);
 where count_56 =1;
 output;
run;

data pos_3;
 set zipcode (keep=zipcode count_25);
 where count_25 =1;
 output;
run;

data pos_4;
 set zipcode (keep=zipcode count_21);
 where count_21 =1;
 output;
run;

proc freq data=zipcode;
tables zipcode / missing;  /* MISSING option treats mising values as a valid category */
run;
