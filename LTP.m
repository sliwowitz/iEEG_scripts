% ktery kanal eeg meril synchronizaci z paralelniho portu?
% 22.1.2014

LPT = 104; %cislo kanalu synchronize 

%vypis casu
for i=1:100, disp(datestr(tabs(i),'dd-mmm-yyyy HH:MM:SS.FFF')), end
close all;
h = figure('Position',[10 100  1200 600]);
pause on
for i=1:size(d,2)
    plot(d(:,i))
    filename = ['d' num2str(i)];
    saveas(h,['./lpt/' filename],'png')
    disp(filename)
    pause(1) %pauza na dve vteriny
end 
