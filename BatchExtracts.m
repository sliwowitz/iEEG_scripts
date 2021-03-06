function [ ] = BatchExtracts( testname,files,kontrasts, intervals, CSelChName, FAZE)

% files = {   'AEdist CHilbert 50-150 -0.5-1.2 refBipo Ep2018-04_CHilb.mat',...
%             'AEdist CMorlet 1-10M -0.5-1.2 refBipo Ep2018-06 FE_CHilb.mat',...
%             'AEdist CMorlet 4-8M -0.5-1.2 refBipo Ep2018-06 FE_CHilb.mat',...
%             'AEdist CMorlet 1-4M -0.5-1.2 refBipo Ep2018-06 FE_CHilb.mat'};       
% 
% testname = 'aedist';
%#ok<*UNRCH>
[ pacienti, setup  ] = pacienti_setup_load( testname );
if ~exist('kontrasts','var') || isempty(kontrasts), kontrasts = 1:numel(setup.stat_kats); end %statisticky kontrast, pokud nezadam zvnejsku, udelam vsechny
if ~exist('intervals','var'), intervals = [0.1 1]; end
if ~exist('FAZE','var'), FAZE = 1; end
pocetcyklu = 0;
for kontrast = 1:numel(kontrasts) %cyklus jen na vypocet celkoveho poctu cyklu pres vsechny kontrasty ve statistice
    stat = setup.stat_kats{kontrast}; %resp setup.stat_kats{1} {2} nebo {3} pro menrot 
    kombinace_kat = combinator(length(stat),2,'p'); %permutace bez opakovani z poctu kategorii
    kombinace_kat = kombinace_kat(kombinace_kat(:,1)>kombinace_kat(:,2),:); %vyberu jen permutace, kde prvni cislo je vetsi nez druhe     
    pocetcyklu = pocetcyklu + numel(files) * size(kombinace_kat,1) ;
end

if FAZE==1 %vytvarim extrakty a CM soubory
    overwrite_extracts = 1; %jestli se maji prepisovat extrakty pro kazdeho pacienta
    overwrite_brainplots = 1;
    overwriteCM = 1; %jestli se maji prepisovat soubory CHilbertMulti
    doIntervalyResp = 1; %jestli se maji hledaty signif soubory pres vsechny pacienty pomoci CN.IntervalyResp, pokud ne, potrebuju uz mit hotove CHilbertMulti soubory
    loadCM = 0; %jestli se maji nacist existujici CM soubory pokud existuji
    brainplots_onlyselch = 0; %generovat CBrainPlot3D jedine ze souboru, kde jsou selected channels
    plotallchns = 0; %jestli generovat obrazky mozku i se vsema kanalama (bez ohledu na signifikanci)        
elseif FAZE == 2 %nove CBrainPloty podle SelCh
    overwrite_extracts = 0; %jestli se maji prepisovat extrakty pro kazdeho pacienta
    overwrite_brainplots = 1;
    overwriteCM = 0; %jestli se maji prepisovat soubory CHilbertMulti
    doIntervalyResp = 0; %jestli se maji hledaty signif soubory pres vsechny pacienty pomoci CN.IntervalyResp, pokud ne, potrebuju uz mit hotove CHilbertMulti soubory
    loadCM = 1; %jestli se maji nacist existujici CM soubory pokud existuji
    brainplots_onlyselch = 1; %generovat CBrainPlot3D jedine ze souboru, kde jsou selected channels
    plotallchns = 1; %jestli generovat obrazky mozku i se vsema kanalama (bez ohledu na signifikanci)   
else
    error('jaka faze?');
end
IntervalyRespSignum = 1; %jestli chci jen kat1>kat2 (1), nebo obracene (-1), nebo vsechny (0)
NLabels = 0; %jestli se maji misto jmen kanalu vypisovat jejich Neurology Labels

if strcmp(testname,'menrot')
    if ~exist('CSelChName','var') || isempty(CSelChName), CSelChName = 'CSelCh_Menrot.mat'; end
    dirCM = 'd:\eeg\motol\CHilbertMulti\Menrot\'; %musi koncit \
    fileCS = ['d:\eeg\motol\CHilbertMulti\Menrot\' CSelChName];
elseif strcmp(testname,'aedist')
    if ~exist('CSelChName','var') || isempty(CSelChName), CSelChName = 'CSelCh_AEdist.mat'; end
    dirCM = 'd:\eeg\motol\CHilbertMulti\Aedist\'; %musi koncit \
    fileCS = ['d:\eeg\motol\CHilbertMulti\Aedist\' CSelChName];
elseif strcmp(testname,'ppa')
    if ~exist('CSelChName','var') || isempty(CSelChName), CSelChName = 'CSelCh_PPA.mat'; end
    dirCM = 'd:\eeg\motol\CHilbertMulti\PPA\'; %musi koncit \
    fileCS = ['d:\eeg\motol\CHilbertMulti\PPA\' CSelChName];
else
    error('neznamy typ testu');
end

%LOG SOUBORY
%1. seznam vsech extraktu
logfilename = ['logs\BatchExtract_' testname '_' datestr(now, 'yyyy-mm-dd_HH-MM-SS') '.log'];
FFFilenames_logname = ['logs\BatchExtractFilenames_' testname '_' datestr(now, 'yyyy-mm-dd_HH-MM-SS') '.xls'];
FFFilenames_XLS = cell(1+pocetcyklu*numel(pacienti),6); 
FFFilenames_XLS(1,:)={'file','fileno','kat','katno','interval','extract'};
%2. soubor na logovani prubehu
[fileID,~] = fopen(logfilename,'wt'); 
%3. tabulka vyslednych CHilbertMulti souboru
tablelog = cell(pocetcyklu+1,8); 
tablelog(1,:) = {'file','fileno','kategorie','interval','stat','result','file','datetime'}; %hlavicky xls tabulky
if FAZE == 2 && exist('fileCS','var') && exist(fileCS,'file')==2 
    CS = CSelCh(fileCS);
end
cyklus = 1;
pocetextracts = 1;

for f = 1:numel(files) %cyklus pres vsechny soubory
    for kontrast = 1:numel(kontrasts) %cyklus pres vsechny kontrasty
        stat = setup.stat_kats{kontrasts(kontrast)};      
%         try
            if doIntervalyResp
                msg = [' --- ' files{f} ': IntervalyResp *********** ']; 
                disp(msg); fprintf(fileID,[ msg '\n']);

                CB = CBrainPlot;      %brainplot na ziskani signif odpovedi               
                CB.IntervalyResp(testname,min(intervals,setup.epochtime(2)),files{f},kontrasts(kontrast),IntervalyRespSignum); %ziskam signif rozdily pro kategorie a mezi kategoriemi pro vsechny pacienty       
                kategorie = find(~cellfun('isempty',strfind(CB.katstr,'X'))); %strfind je jenom case sensitivni
                katsnames = CB.katstr;
            else
                msg = [' --- ' files{f} ': Load *********** '];
                disp(msg); fprintf(fileID,[ msg '\n']);                
                idpac = 1; E = [];                
                while isempty(E)
                    if pacienti(idpac).todo == 1
                        E = pacient_load(pacienti(idpac).folder,testname,files{f},[],[],[],0); %nejspis objekt CHilbert, pripadne i jiny; loadall = 0
                    end
                    idpac = idpac +1;
                end
                E.SetStatActive(kontrasts(kontrast));
                katsnames = E.GetKatsNames();
                kategorie = find(~cellfun('isempty',strfind(katsnames,'X'))); %strfind je jenom case sensitivni - cisla kategorii s kombinacemi podminek
            end
            
            for kat = 1:numel(kategorie)
                katstr = katsnames{kategorie(kat)}; %jmeno kombinace podminek z CB, naprikad znackaXvy
                for intv = 1:size(intervals,1) %cyklus pres intervaly
                    intvstr = sprintf('(%1.1f-%1.1f)',intervals(intv,:)); %pojmenovani intervalu
%                 try
                    label = [katstr '_' intvstr '_sig' num2str(IntervalyRespSignum)];
                    outfilename = [dirCM 'CM ' label ' ' files{f}]; %jmeno souboru CHilbertMulti
                    CM = CHilbertMulti; 
                    if exist(outfilename,'file')==2 && overwriteCM == 0 && loadCM == 1
                        msg = [ ' --- ' strrep(outfilename,'\','\\') ' nacteno '  datestr(now)];
                        disp(msg); fprintf(fileID,[ msg '\n']);                     
                        tablelog(cyklus+1,:) = { files{f}, num2str(f), katstr,intvstr,cell2str(stat), 'nacteno', outfilename,datestr(now) };                     
                        CM.Load(outfilename);                        
                    elseif doIntervalyResp || ~loadCM
                        msg = [ ' --- ' strrep(outfilename,'\','\\') ' zpracovavam '  datestr(now)]; 
                        disp(msg); fprintf(fileID,[ msg '\n']);  
                            
                        if doIntervalyResp
                        %vytvorim extrakty podle tabulky PAC, pro vsechny pacienty a pro tuto kategorii
                            filenames_extract = CM.ExtractData(CB.PAC{intv,kategorie(kat)},testname,files{f},label,overwrite_extracts); 
                        else
                            filenames_extract = CM.FindExtract(testname,label,files{f});   
                            filenames_extract = filenames_extract(:,1);
                        end

                        FFFilenames_XLS(pocetextracts:pocetextracts+numel(filenames_extract)-1,:) = ...
                            cat(2,repmat({files{f},f,katstr,kat,intvstr},numel(filenames_extract),1),filenames_extract);
                        pocetextracts = pocetextracts + numel(filenames_extract);                
                        
                        %FILES = CM.TestExtract(filenames_extract);
                        CM.ImportExtract(filenames_extract,label);
                        CM.ResponseSearch(0.1,stat); 
                        CM.SetStatActive(2);
                        CM.ResponseSearch(0.1,setup.stat_kats{1}); %vzdy budu mit jako druhou statistiku vse proti vsemu
                        CM.SetStatActive(1);%kvuli pozdejsimu exportu do BPD
                        CM.Save(outfilename);

                        msg = [ ' --- ' files{f} ': ' label ' OK '  datestr(now)];
                        disp(msg); fprintf(fileID,[ msg '\n']);            
                        tablelog(cyklus+1,:) = { files{f}, num2str(f), katstr,intvstr,cell2str(stat), 'saved', outfilename,datestr(now) }; 
                    else
                        msg = [ ' --- ' strrep(outfilename,'\','\\') ' nevytvoreno, nenacteno '  datestr(now)];
                        disp(msg); fprintf(fileID,[ msg '\n']);   
                        tablelog(cyklus+1,:) = { files{f}, num2str(f), katstr,intvstr,cell2str(stat), 'nothing to do', outfilename,datestr(now) }; 
                    end
                    if exist('CS','var')                        
                        selCh = CS.GetSelCh(CM); %pokud se tam nazev souboru najde, vlozi se selected channels, jinak ne
                    else
                        selCh = [];
                    end
                    if ~brainplots_onlyselch || ~isempty(selCh) %pokud negenerovat jen pro selch, nebo pokud nejsou prazne selch
                        CBo = CBrainPlot; %brainplot na generovani obrazku mozku                        
                        BPD = CM.ExtractBrainPlotData(iff(plotallchns,[kategorie(kat) numel(katsnames)],kategorie(kat)),IntervalyRespSignum,0); %vytvori data pro import do CBrainPlot
                                %kategorie AllEl je vzdy posledni v katsnames
                        CBo.ImportData(BPD); %naimportuje data z CHilbertMulti
                        CBo.PlotBrain3DConfig(struct('overwrite',overwrite_brainplots,'NLabels',NLabels));
                        CBo.PlotBrain3D(iff(plotallchns,[1 2],1)); %vykresli obrazek mozku
                    end
%                 catch exception 
%                     errorMessage = exceptionLog(exception);                            
%                     disp(errorMessage);  fprintf(fileID,[errorMessage '\n']);   %zobrazim hlasku, zaloguju, ale snad to bude pokracovat dal                                        
%                     tablelog(cyklus+1,:) = { files{f}, num2str(f), katstr, 'error', exception.message , datestr(now)}; 
%                     clear CM; 
%                 end 
                end
                cyklus = cyklus + 1;
                xlswrite([logfilename '.xls'],tablelog); %budu to psat znova po kazdem souboru, abych o log neprisel, pokud se program zhrouti
                xlswrite(FFFilenames_logname,FFFilenames_XLS); %budu to psat znova po kazdem souboru, abych o log neprisel, pokud se program zhrouti
            end
%         catch exception
%             errorMessage = exceptionLog(exception);                          
%             disp(errorMessage);  fprintf(fileID,[errorMessage '\n']);   %zobrazim hlasku, zaloguju, ale snad to bude pokracovat dal                                        
%             tablelog(cyklus+1,:) = { files{f}, num2str(f), 'no kat', 'error', exception.message , datestr(now)}; 
%             clear CB;        
%             cyklus = cyklus + 1;
%             xlswrite([logfilename '.xls'],tablelog); %budu to psat znova po kazdem souboru, abych o log neprisel, pokud se program zhrouti
%             xlswrite(FFFilenames_logname,FFFilenames_XLS); %budu to psat znova po kazdem souboru, abych o log neprisel, pokud se program zhrouti
%         end
    end
end

%system('shutdown -h') 