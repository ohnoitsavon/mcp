unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  FileCtrl, FileUtil, Windows, Messages, SysUtils, Variants, Classes, Graphics,
  Controls, Forms, Dialogs, StdCtrls, ShellAPI, ComCtrls, CommCtrl, Menus,
  Process, lclintf, JwaTlHelp32, MMSystem, Unit2,
  {$ifdef unix}
  cthreads,
  cmem, // the c memory manager is on some systems much faster for multi-threading
  {$endif}
  Interfaces; // this includes the LCL widgetset

type

  { TMainForm }

  TMainForm = class(TForm)
    btnShowLog: TButton;
    btnBCheck: TButton;
    btnBConvert: TButton;
    btnSCheck: TButton;
    btnSConvert: TButton;
    btnCLRscr: TButton;
    btnOpendir: TButton;
    btnCancel: TButton;
    cbbErrorLevel: TComboBox;
    cbbFType1: TComboBox;
    cbbFType2: TComboBox;
    cbbFormat: TComboBox;
    dlgOpenSingleF: TOpenDialog;
    lbCheckLevel: TLabel;
    lbFormat: TLabel;
    lbFFCMD: TLabel;
    miGPU: TMenuItem;
    miCleanLog: TMenuItem;
    miAbout: TMenuItem;
    miHelp: TMenuItem;
    miExit: TMenuItem;
    miHelpPage: TMenuItem;
    txtAdv: TEdit;
    lblFilesCheckedCount: TLabel;
    lstFileList: TListBox;
    miConvSF: TMenuItem;
    miConvB: TMenuItem;
    miCheckB: TMenuItem;
    miCheckSF: TMenuItem;
    mmMCP: TMainMenu;
    miFile: TMenuItem;
    mmoDisplay: TMemo;
    pbProgress: TProgressBar;
    pbWorking: TProgressBar;
    lbFileType: TLabel;
    lbFileType1: TLabel;
    procedure btnBCheckClick(Sender: TObject);
    procedure btnBConvertClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnCLRscrClick(Sender: TObject);
    procedure btnOpendirClick(Sender: TObject);
    procedure btnSCheckClick(Sender: TObject);
    procedure btnSConvertClick(Sender: TObject);
    procedure btnShowLogClick(Sender: TObject);
    procedure cbbFormatChange(Sender: TObject);
    procedure cbbFType2Change(Sender: TObject);
    procedure FormClose(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure AddAllFilesInDir(const Dir,ftyp: string);
    procedure miAboutClick(Sender: TObject);
    procedure miCheckBClick(Sender: TObject);
    procedure miCheckSFClick(Sender: TObject);
    procedure miCleanLogClick(Sender: TObject);
    procedure miConvBClick(Sender: TObject);
    procedure miConvSFClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure miGPUClick(Sender: TObject);
    procedure miHelpPageClick(Sender: TObject);
    procedure runcode(fExec,dir,Args:string;cmd:integer);
    procedure CheckCode(multifile:integer);
    procedure ConvertCode(multifile:integer);
    function CheckFFMPEG():boolean;

  private
    { private declarations }
  public
    { public declarations }
  end;

  TFFMpegCMDs = array of array of String;
  TFileTypes = array of String;


var
  MainForm: TMainForm;
  ffmpeglocation,chosenDirectory,filetype1,filetype2,singlefile,timedatestr, logdir, AdvString:string;
  ErrorLevel, FormatNo, GPUacc, nooffiles, totalerrors, closeprogint, ffmpegrun , latecan , mainrunning: integer;
  medtype,medtype2, ELfile, AV1file, AV2file, CMDString, PNFile, GPUFile : TextFile;
  FileTypes: TFileTypes;
  FFMpegCMDs: TFFMpegCMDs;
  strlistCMDs: TStringList;


implementation

{$R *.lfm}


function KillTask(ExeFileName: string): Integer; //lib function Kills exe name
const
  PROCESS_TERMINATE = $0001;
var
  ContinueLoop: BOOL;
  FSnapshotHandle: THandle;
  FProcessEntry32: TProcessEntry32;
begin
  Result := 0;
  FSnapshotHandle := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  FProcessEntry32.dwSize := SizeOf(FProcessEntry32);
  ContinueLoop := Process32First(FSnapshotHandle, FProcessEntry32);

  while Integer(ContinueLoop) <> 0 do
  begin
    if ((UpperCase(ExtractFileName(FProcessEntry32.szExeFile)) =
      UpperCase(ExeFileName)) or (UpperCase(FProcessEntry32.szExeFile) =
      UpperCase(ExeFileName))) then
      Result := Integer(TerminateProcess(
                        OpenProcess(PROCESS_TERMINATE,
                                    BOOL(0),
                                    FProcessEntry32.th32ProcessID),
                                    0));
     ContinueLoop := Process32Next(FSnapshotHandle, FProcessEntry32);
  end;
  CloseHandle(FSnapshotHandle);
end;

{Check thread}

Type
   TCheckThread = class(TThread)
   private
     procedure OnThredDone;
   protected
     procedure Execute; override;
   public
     Constructor Create(CreateSuspended : boolean);
     var MultiFile:integer;
   end;

 constructor TCheckThread.Create(CreateSuspended : boolean);
 begin
   inherited Create(CreateSuspended); // because this is black box in OOP and can reset inherited to the opposite again...
   FreeOnTerminate := True;  // better code...
 end;

procedure TCheckThread.OnThredDone;
begin
  mainrunning:=0;

  //show all things
  MainForm.pbWorking.Style:=pbstNormal;

  MainForm.btnSCheck.Enabled := true;
  MainForm.btnBCheck.Enabled := true;
  MainForm.btnSConvert.Enabled := true;
  MainForm.btnBConvert.Enabled := true;
  MainForm.cbbFType1.Enabled := true;
  MainForm.cbbFType2.Enabled := true;
  MainForm.cbbErrorLevel.Enabled := true;
  MainForm.cbbFormat.Enabled := true;
  MainForm.txtAdv.Enabled := true;
  MainForm.miCheckSF.Enabled := true;
  MainForm.miCheckB.Enabled := true;
  MainForm.miConvSF.Enabled := true;
  MainForm.miConvB.Enabled := true;
  MainForm.miCleanLog.Enabled := true;
  MainForm.miGPU.Enabled := true;
  MainForm.btnCancel.Visible := false;
  MainForm.btnCLRscr.Visible := true;
  MainForm.btnOpendir.Visible := true;

  //if erros - show log
  if (totalerrors > 0) and (latecan = 0) then
  begin
       MainForm.btnShowLog.Visible := true;
       Application.MessageBox('Check completed with ERRORS!','Media Check Pro', MB_ICONERROR+MB_OK);
  end
  else
  begin
       //if you didnt cancel
       if latecan = 0 then
       begin
         //if no files show error
         if nooffiles = 0 then
         begin
              MainForm.btnCLRscrClick(self);
              Application.MessageBox('No files found!','Media Check Pro', MB_ICONERROR+MB_OK);
         end
         else   //no errors show success
         begin
              PlaySound('SND_ALIAS_SYSTEMDEFAULT',0,SND_ASYNC);
              Application.MessageBox('Check completed successfully!','Media Check Pro', MB_OK);
         end;
       end
       else //you canceled
       begin
           MainForm.btnCLRscrClick(self);
           Application.MessageBox('Check Canceled','Media Check Pro',MB_ICONWARNING + MB_OK);
       end;
  end;
end;

procedure TCheckThread.Execute;
 begin
    while (not Terminated) do
     begin
       {here goes the code of the main thread loop]}
       MainForm.CheckCode(MultiFile);
       Synchronize(@OnThredDone);
       EndThread;
     end;
 end;

{Convert thread}

Type
   TConvertThread = class(TThread)
   private
     procedure OnThredDone;
   protected
     procedure Execute; override;
   public
     Constructor Create(CreateSuspended : boolean);
     var MultiFile:integer;
   end;

 constructor TConvertThread.Create(CreateSuspended : boolean);
 begin
   inherited Create(CreateSuspended); // because this is black box in OOP and can reset inherited to the opposite again...
   FreeOnTerminate := True;  // better code...
 end;

procedure TConvertThread.OnThredDone;
begin
   mainrunning:=0;

   //show all things
   MainForm.pbWorking.Style:=pbstNormal;

   MainForm.btnSCheck.Enabled := true;
   MainForm.btnBCheck.Enabled := true;
   MainForm.btnSConvert.Enabled := true;
   MainForm.btnBConvert.Enabled := true;
   MainForm.cbbFType1.Enabled := true;
   MainForm.cbbFType2.Enabled := true;
   MainForm.cbbErrorLevel.Enabled := true;
   MainForm.cbbFormat.Enabled := true;
   MainForm.txtAdv.Enabled := true;
   MainForm.miCheckSF.Enabled := true;
   MainForm.miCheckB.Enabled := true;
   MainForm.miConvSF.Enabled := true;
   MainForm.miConvB.Enabled := true;
   MainForm.miCleanLog.Enabled := true;
   MainForm.miGPU.Enabled := true;
   MainForm.btnCancel.Visible := false;
   MainForm.btnCLRscr.Visible := true;
   MainForm.btnOpendir.Visible := true;

   //if erros - show log
   if (totalerrors > 0) and (latecan = 0) then
   begin
       MainForm.btnShowLog.Visible := true;
       Application.MessageBox('Conversion completed with ERRORS!','Media Check Pro', MB_ICONERROR+MB_OK);
   end
   else
   begin
       //if you didnt cancel
       if latecan = 0 then
       begin
         //if no files show error
         if nooffiles = 0 then
         begin
           MainForm.btnCLRscrClick(self);
           Application.MessageBox('No files found!','Media Check Pro', MB_ICONERROR+MB_OK);
         end
         else //no errors show success
           begin
             PlaySound('SND_ALIAS_SYSTEMDEFAULT',0,SND_ASYNC);
             Application.MessageBox('Conversion completed successfully!','Media Check Pro', MB_OK);
           end;
       end
       else //you canceled
       begin
           MainForm.btnCLRscrClick(self);
           Application.MessageBox('Conversion Canceled','Media Check Pro',MB_ICONWARNING + MB_OK);
       end;
   end;
end;

procedure TConvertThread.Execute;
 begin
    while (not Terminated) do
     begin
       {here goes the code of the main thread loop]}
       MainForm.ConvertCode(MultiFile);
       Synchronize(@OnThredDone);
       EndThread;
     end;
 end;

{ TMainForm }

procedure savefiles; //save pref files
begin
  AssignFile(medtype, 'mtype.xmcpcontent');
  Rewrite(medtype);
  Write(medtype, filetype1);
  CloseFile(medtype);

  AssignFile(medtype2, 'mtype2.xmcpcontent');
  Rewrite(medtype2);
  Write(medtype2, filetype2);
  CloseFile(medtype2);

  AssignFile(ELfile, 'el.xmcpcontent');
  Rewrite(ELfile);
  Write(ELfile, IntToStr(ErrorLevel));
  CloseFile(ELfile);

  AssignFile(PNFile, 'pn.xmcpcontent');
  Rewrite(PNFile);
  Write(PNFile, IntToStr(FormatNo));
  CloseFile(PNFile);

  AssignFile(GPUFile, 'gpu.xmcpcontent');
  Rewrite(GPUFile);
  Write(GPUFile, IntToStr(GPUacc));
  CloseFile(GPUFile);

  AssignFile(CMDString, 'cstr.xmcpcontent');
  Rewrite(CMDString);
  Write(CMDString, AdvString);
  CloseFile(CMDString);
end;

procedure updatepresetlist;
var i,j,k,scomplete:integer;
begin
   strlistCMDs.Clear;
   MainForm.cbbFormat.Clear;
   i:=0;
   j:=0;
   scomplete:=0;
   repeat
        if UpperCase(MainForm.cbbFType2.Text) = UpperCase(FileTypes[i]) then
        begin
          j := i;
          i := Length(FileTypes);
          scomplete := 1;
        end
        else i:=i+1;
   until i > Length(FileTypes)-1; //make it 0 start

   if scomplete = 1 then
   begin
      i:=0;
      k:=0;
      repeat
         if FFMpegCMDs[i,0] = '!--!' then
         begin
           if k = j then
           begin
              j := i;
              i := Length(FFMpegCMDs);
           end
           else k := k+1;
         end;
         i:=i+1;
      until i > Length(FFMpegCMDs)-1; //make it 0 start

      i:=j+1;
      repeat
         if FFMpegCMDs[i,0] = '!--!' then
         begin
           i := Length(FFMpegCMDs);
         end
         else
         begin
           MainForm.cbbFormat.Items.Add(FFMpegCMDs[i,0]);
           strlistCMDs.Add(FFMpegCMDs[i,1]);
           i:=i+1;
         end;
      until i > Length(FFMpegCMDs)-1; //make it 0 start
   end
   else
   begin
      MainForm.cbbFormat.Items.Add('Custom');
      strlistCMDs.Add('');
   end;
end;

function TMainForm.CheckFFMPEG():boolean;  //check if ffmpeg exists
begin
   if not FileExists(ffmpeglocation+'/ffmpeg.exe') then //if ffmpeg is not in application dir
   begin
      //show error message
      ShowMessage('"ffmpeg.exe" was not found in - ' + ffmpeglocation
      + sLineBreak + sLineBreak +'Please copy your verison of "ffmpeg.exe" to this location and reopen the program.');
      //close the app
      MainForm.Close;
      CheckFFMPEG:=true;
   end
   else CheckFFMPEG:=false; //return false if file is there
end;

procedure TMainForm.ConvertCode(multifile:integer);  //COMMENT!!!!!
var batchcount: Integer;
    tempsfile,tempsfile2,tempsfile3,advCString,strGPU: string;
begin
    //set cancel
    latecan := 0;

    if CheckFFMPEG then exit;

    timedatestr:=FormatDateTime('YYYYMMDD-HHMMSSZZZ',Now);

    btnCLRscrClick(self);

    btnSCheck.Enabled := false;
    btnBCheck.Enabled := false;
    btnSConvert.Enabled := false;
    btnBConvert.Enabled := false;
    cbbFType1.Enabled := false;
    cbbFType2.Enabled := false;
    cbbErrorLevel.Enabled := false;
    cbbFormat.Enabled := false;
    txtAdv.Enabled := false;
    miCheckSF.Enabled := false;
    miCheckB.Enabled := false;
    miConvSF.Enabled := false;
    miConvB.Enabled := false;
    miCleanLog.Enabled := false;
    miGPU.Enabled := false;
    btnCLRscr.Visible := false;
    btnShowLog.Visible := false;

    //save vars
    filetype1 := UpperCase(cbbFType1.Text);
    filetype2 := UpperCase(cbbFType2.Text);

    advCString := txtAdv.Text;

    if GPUacc = 1 then
     strGPU:='-hwaccel nvdec'
    else
     strGPU:='';

    pbProgress.Style:=pbstMarquee;

    if multifile = 1 then
    begin
      pbProgress.Style:= pbstNormal;

      mmoDisplay.Lines.Add('Searching For File(s)');
      lblFilesCheckedCount.Caption := 'Searching For File(s)';
      mmoDisplay.Lines.Add('');

      lstFileList.Clear;
      lstFileList.Items.BeginUpdate;

      if filetype1 = '* (ALL FILES)' then
         AddAllFilesInDir(chosenDirectory,'*')
      else
         AddAllFilesInDir(chosenDirectory,filetype1);


      lstFileList.Items.EndUpdate;

      nooffiles := lstFileList.Items.Count;
    end
    else nooffiles := 1;

    if nooffiles = 0 then exit;

    pbProgress.Min := 0;
    pbProgress.Max := nooffiles;
    pbProgress.Step := 1;
    pbProgress.Position := 0;
    totalerrors := 0;

    for batchcount := 0 to nooffiles-1 do
    begin
        if closeprogint = 1 then exit;

        lblFilesCheckedCount.Caption := 'Checking for FFMPEG';

        if FileExists(ffmpeglocation+'/ffmpeg.exe') then
        begin
             RenameFile(ffmpeglocation+'/ffmpeg.exe',ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe');
        end;

        repeat
        until FileExists(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe');

        lblFilesCheckedCount.Caption := 'Converting (' + IntToStr(pbProgress.Position +1 ) + '/' + IntToStr(nooffiles) + ')';
        mmoDisplay.Lines.Add('Converting (' + IntToStr(pbProgress.Position + 1) + '/' + IntToStr(nooffiles) + '):');

        if multifile = 0 then
           tempsfile:=singlefile
        else
           tempsfile:=lstFileList.Items[batchcount];

        mmoDisplay.Lines.Add(tempsfile);

        tempsfile3 := tempsfile;
        if filetype1 <> '* (ALL FILES)' then
        delete(tempsfile3, length(tempsfile3)-length(filetype1), length(filetype1)+1);

        if FileExists(tempsfile3 + '.' + filetype2) then
           tempsfile2 := tempsfile3 + '-' + copy(timedatestr,10,9)
        else tempsfile2 := tempsfile3;

        ffmpegrun:=1;

        runcode('cmd.exe',ffmpeglocation,'/c '+timedatestr+'_ffmpeg '+strGPU+' -i "' + tempsfile + '" '+advCString+' "'+ tempsfile2 + '.' + filetype2 + '" 2>&1 | mtee "'+tempsfile+'.xmcpcheck" ',1);

        ffmpegrun:=0;

        if FileExists(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe') then
        begin
             RenameFile(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe',ffmpeglocation+'/ffmpeg.exe');
        end;

        if FileExists(tempsfile+'.log') then
        begin
             DeleteFile(tempsfile+'.log');
        end;

        //tempfile.xmcpcheck

        if FileUtil.FileSize(tempsfile2+'.'+filetype2)<=0 then
        begin
          mmoDisplay.Lines.Add('');
          mmoDisplay.Lines.Add('!  Error converting file  !');
          totalerrors := totalerrors + 1;
          if FileExists(tempsfile2+'.'+filetype2) then
          begin
            DeleteFile(tempsfile2+'.'+filetype2);
          end;
        end
        else
        begin
          if FileExists(tempsfile+'.xmcpcheck') then
          begin
            DeleteFile(tempsfile+'.xmcpcheck');
          end;
          mmoDisplay.Lines.Add('Good');
        end;

        pbProgress.Style:=pbstNormal;
        pbProgress.StepIt;
        MainForm.Update;

        mmoDisplay.Lines.Add('');
    end;

    if closeprogint = 1 then exit;

    mmoDisplay.Lines.Add('Cleaning Up File(s)');
    lblFilesCheckedCount.Caption := 'Cleaning Up File(s)';

    runcode(ExtractFilePath(Application.ExeName)+'/MCPclean.bat',chosenDirectory,'',0);

    mmoDisplay.Lines.Add('');
    mmoDisplay.Lines.Add('Conversion Complete! on ' + IntToStr(nooffiles) + ' file(s)');
    mmoDisplay.Lines.Add('');

    if FileExists(chosenDirectory+'/ERRORS.log') then
    begin
      RenameFile(chosenDirectory+'/ERRORS.log',chosenDirectory+'/ERRORS-'+timedatestr+'.log');
      mmoDisplay.Lines.Add('Total errors: '+IntToStr(totalerrors));
      mmoDisplay.Lines.Add('');
      lblFilesCheckedCount.Caption := 'Errors found in ' +IntToStr(totalerrors)+'/'+IntToStr(nooffiles) + ' file(s)';
      SendMessage(pbProgress.Handle, PBM_SETSTATE, PBST_ERROR, 0);
    end
    else
    begin
      lblFilesCheckedCount.Caption := 'Conversion Complete! on ' + IntToStr(nooffiles) + ' file(s)';
    end;

end;

procedure TMainForm.CheckCode(multifile:integer);
var fferrorset,batchcount: Integer;
    tempsfile, strGPU: string;
begin
    //set cancel
    latecan := 0;

    if CheckFFMPEG then exit; //exit if no ffmpeg

    timedatestr:=FormatDateTime('YYYYMMDD-HHMMSSZZZ',Now);  //get date

    btnCLRscrClick(self);  //clear screen

    pbProgress.Style:=pbstMarquee; //set progress bar type

    //hide clickable elements
    btnSCheck.Enabled := false;
    btnBCheck.Enabled := false;
    btnSConvert.Enabled := false;
    btnBConvert.Enabled := false;
    cbbFType1.Enabled := false;
    cbbFType2.Enabled := false;
    cbbErrorLevel.Enabled := false;
    cbbFormat.Enabled := false;
    txtAdv.Enabled := false;
    miCheckSF.Enabled := false;
    miCheckB.Enabled := false;
    miConvSF.Enabled := false;
    miConvB.Enabled := false;
    miCleanLog.Enabled := false;
    miGPU.Enabled := false;
    btnCLRscr.Visible := false;
    btnShowLog.Visible := false;

    //save vars + set error level
    filetype1 := UpperCase(cbbFType1.Text);
    ErrorLevel := cbbErrorLevel.ItemIndex;
    If ErrorLevel = 0 then
          fferrorset := 16
    else
    begin
          if ErrorLevel = 1 then fferrorset := 24;
    end;

    if GPUacc = 1 then
     strGPU:='-hwaccel nvdec'
    else
     strGPU:='';

    //if multiple files
    if multifile = 1 then
    begin
      pbProgress.Style:= pbstNormal; //set progress bar style
      //write to memo
      mmoDisplay.Lines.Add('Searching For File(s)');
      lblFilesCheckedCount.Caption := 'Searching For File(s)';
      mmoDisplay.Lines.Add('');

      //clear file list
      lstFileList.Clear;
      //add files to list
      lstFileList.Items.BeginUpdate;

      if filetype1 = '* (ALL FILES)' then
         AddAllFilesInDir(chosenDirectory,'*')
      else
         AddAllFilesInDir(chosenDirectory,filetype1);

      lstFileList.Items.EndUpdate;
      //set number of files
      nooffiles := lstFileList.Items.Count;
    end
    else nooffiles := 1; //else set to one file

    if nooffiles = 0 then exit; // if no files exit

    //setup progress bar
    pbProgress.Min := 0;
    pbProgress.Max := nooffiles;
    pbProgress.Step := 1;
    pbProgress.Position := 0;

    //reset total erros
    totalerrors := 0;

    // for each file
    for batchcount := 0 to nooffiles-1 do
    begin
        if closeprogint = 1 then exit;

        //check for ffmpeg
        lblFilesCheckedCount.Caption := 'Checking for FFMPEG';

        //rename ffmpeg to individual name
        if FileExists(ffmpeglocation+'/ffmpeg.exe') then
        begin
             RenameFile(ffmpeglocation+'/ffmpeg.exe',ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe');
        end;

        repeat //wait untill it has renamed
        until FileExists(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe');

        //write status to memo
        lblFilesCheckedCount.Caption := 'Checking (' + IntToStr(pbProgress.Position +1 ) + '/' + IntToStr(nooffiles) + ')';
        mmoDisplay.Lines.Add('Checking (' + IntToStr(pbProgress.Position + 1) + '/' + IntToStr(nooffiles) + '):');

        //if single file
        if multifile = 0 then
           tempsfile:=singlefile //set to file name/dir
        else
           tempsfile:=lstFileList.Items[batchcount];   //get name/dir from list

        mmoDisplay.Lines.Add(tempsfile);  //write dir to memo

        ffmpegrun:=1; //set ffmpeg to running

        //run check code
        runcode('cmd.exe',ffmpeglocation,'/c '+timedatestr+'_ffmpeg '+strGPU+' -v ' + IntToStr(fferrorset) + ' -i "' + tempsfile + '" -f null - 2>&1 | mtee "'+tempsfile+'.xmcpcheck" ',0);
        { info...
        ‘quiet, -8’ Show nothing at all; be silent.
        ‘panic, 0’    Only show fatal errors which could lead the process to crash, such as and assert failure. This is not currently used for anything.
        ‘fatal, 8’    Only show fatal errors. These are errors after which the process absolutely cannot continue after.
        ‘error, 16’   Show all errors, including ones which can be recovered from.
        ‘warning, 24’ Show all warnings and errors. Any message related to possibly incorrect or unexpected events will be shown.
        ‘info, 32’    Show informative messages during processing. This is in addition to warnings and errors. This is the default value.
        ‘verbose, 40’ Same as info, except more verbose.
        ‘debug, 48’   Show everything, including debugging information.
         }

        ffmpegrun:=0; //set ffmpeg to stopped

        //rename ffmpeg back to ffmpeg.exe
        if FileExists(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe') then
        begin
             RenameFile(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe',ffmpeglocation+'/ffmpeg.exe');
        end;

        if closeprogint = 1 then
        begin
          pbProgress.Style:=pbstNormal;
          exit;
        end;

        //if log file exists for file delete it.
        if FileExists(tempsfile+'.log') then
        begin
             DeleteFile(tempsfile+'.log');
        end;

        //delete log files with no size
        runcode(ExtractFilePath(Application.ExeName)+'/MCPcleanBatchSingle.bat',chosenDirectory,'',0);

        //if files remain write to screen + add to total errors
        if FileExists(tempsfile+'.xmcpcheck') then
        begin
             mmoDisplay.Lines.Add('');
             mmoDisplay.Lines.Add('!  Errors were found in this file  !');
             totalerrors := totalerrors + 1;
        end
        else  mmoDisplay.Lines.Add('Good'); //file good

        //step progress bar
        pbProgress.Style:=pbstNormal;
        pbProgress.StepIt;
        MainForm.Update;

        mmoDisplay.Lines.Add('');
    end;

    //when files done write to screen
    mmoDisplay.Lines.Add('Cleaning Up File(s)');
    lblFilesCheckedCount.Caption := 'Cleaning Up File(s)';

    //run cleanup program, creates master log file
    runcode(ExtractFilePath(Application.ExeName)+'/MCPclean.bat',chosenDirectory,'',0);

    //write to screen
    mmoDisplay.Lines.Add('');
    mmoDisplay.Lines.Add('Check Complete! on ' + IntToStr(nooffiles) + ' file(s)');
    mmoDisplay.Lines.Add('');

    //if log file exists
    if FileExists(chosenDirectory+'/ERRORS.log') then
    begin
      //rename to date time
      RenameFile(chosenDirectory+'/ERRORS.log',chosenDirectory+'/ERRORS-'+timedatestr+'.log');
      //write to screen
      mmoDisplay.Lines.Add('Total errors: '+IntToStr(totalerrors));
      mmoDisplay.Lines.Add('');
      lblFilesCheckedCount.Caption := 'Errors found in ' +IntToStr(totalerrors)+'/'+IntToStr(nooffiles) + ' file(s)';
      //change error bar colour
      SendMessage(pbProgress.Handle, PBM_SETSTATE, PBST_ERROR, 0);
    end
    else
    begin
      lblFilesCheckedCount.Caption := 'Check Complete! on ' + IntToStr(nooffiles) + ' file(s)';
    end;

end;

procedure TMainForm.AddAllFilesInDir(const Dir, ftyp: string);   //find all files of type
var
SR: TSearchRec;
begin
if FindFirst(IncludeTrailingBackslash(Dir) + '*.*', faAnyFile or faDirectory, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        if (ftyp = '*') or (UpperCase(ExtractFileExt(SR.Name)) = UpperCase('.'+ftyp)) then
         begin
            lstFileList.Items.Add(Dir + '\' + SR.Name);
         end;
      end
      else if (SR.Name <> '.') and (SR.Name <> '..') then
        AddAllFilesInDir(IncludeTrailingBackslash(Dir) + SR.Name,ftyp);  // recursive call!
    until FindNext(Sr) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TMainForm.miAboutClick(Sender: TObject);
begin
 frmAbout.Visible:=true;
end;

procedure TMainForm.miCheckBClick(Sender: TObject);
begin
  btnBCheckClick(Self);
end;

procedure TMainForm.miCheckSFClick(Sender: TObject);
begin
  btnSCheckClick(Self);
end;

procedure TMainForm.miCleanLogClick(Sender: TObject);
var i:integer;
begin
  if mainrunning <> 1 then
  begin
    case QuestionDlg ('Media Check Pro - Clean Log Files', 'Do you want to delete all ''.xmcpcheck'' and ''.log'' files in the chosen directory?',mtCustom,[mrYes,'Choose Directory', mrCancel,'Cancel','IsCancel'],'') of
    mrYes:
      begin
        if SelectDirectory('Select Directory', '', logdir) then
        begin
             case QuestionDlg ('Media Check Pro - Clean Log Files', 'Do you want to delete all ''.xmcpcheck'' and ''.log'' files in "' + logdir + '"?',mtCustom,[mrYes,'Yes', mrCancel,'Cancel','IsCancel'],'') of
             mrYes:
               begin
                 //clear file list
                 lstFileList.Clear;
                 //add files to list
                 lstFileList.Items.BeginUpdate;
                 AddAllFilesInDir(logdir,'xmcpcheck');
                 AddAllFilesInDir(logdir,'log');
                 lstFileList.Items.EndUpdate;
                 //set number of files
                 nooffiles := lstFileList.Items.Count;

                 for i := 0 to nooffiles-1 do
                 begin
                   if FileExists(lstFileList.Items[i]) then
                   begin
                        DeleteFile(lstFileList.Items[i]);
                   end;
                 end;

                 Application.MessageBox(PChar(inttostr(nooffiles)+' File(s) Deleted!'),'Media Check Pro - Clean Log Files', MB_OK);

               end;
             mrCancel:{do nothing};
             end;
        end;
      end;
    mrCancel:{do nothing};
    end;
  end
  else
  begin
       Application.MessageBox('This can not be run while checking or converting!','Media Check Pro - Clean Log Files', MB_OK);
  end;



end;

procedure TMainForm.miConvBClick(Sender: TObject);
begin
 btnBconvertClick(Self);
end;

procedure TMainForm.miConvSFClick(Sender: TObject);
begin
 btnSConvertClick(Self);
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.miGPUClick(Sender: TObject);
begin
  if GPUacc = 1 then
  begin
    GPUacc := 0;
    miGPU.Caption:='Enable NVIDIA GPU Acceleration';
  end
  else
  begin
    GPUacc := 1;
    miGPU.Caption:='Disable NVIDIA GPU Acceleration';
  end;
end;

procedure TMainForm.miHelpPageClick(Sender: TObject);
begin
  OpenDocument(ExtractFilePath(Application.ExeName)+'help.html');
end;

procedure TMainForm.btnShowLogClick(Sender: TObject);  //show last log file
begin
  if FileExists(chosenDirectory+'/ERRORS-'+timedatestr+'.log') then
  begin
    OpenDocument(chosenDirectory+'/ERRORS-'+timedatestr+'.log');
  end;
end;

procedure TMainForm.cbbFormatChange(Sender: TObject);
begin
  txtAdv.Text := strlistCMDs[cbbFormat.ItemIndex];
end;

procedure TMainForm.cbbFType2Change(Sender: TObject);
begin
  updatepresetlist;
  cbbFormat.ItemIndex:=0;
  txtAdv.Text := strlistCMDs[cbbFormat.ItemIndex];
end;

procedure TMainForm.btnCLRscrClick(Sender: TObject);    //clear screen
begin
  mmoDisplay.Lines.Clear;
  pbProgress.Position := 0;
  lblFilesCheckedCount.Caption := '';
  btnCLRscr.Visible := false;
  btnShowLog.Visible := false;
  btnOpendir.Visible := false;
  MainForm.Update;
  SendMessage(pbProgress.Handle, PBM_SETSTATE, PBST_NORMAL, 0);
  runcode(ExtractFilePath(Application.ExeName)+'/MCPclean.bat',chosenDirectory,'',0);
end;

procedure TMainForm.btnOpendirClick(Sender: TObject);  //open dir
begin
  OpenDocument(chosenDirectory);
end;

procedure TMainForm.runcode(fExec,dir,Args:string;cmd:integer); //runs given windows code/exe
var
  AProcess     : TProcess;
begin
  //set process
  AProcess := TProcess.Create(nil);
  AProcess.Executable := fExec;
  AProcess.CurrentDirectory:= dir;
  AProcess.Parameters.Add(Args);

  AProcess.Options := [poWaitOnExit, poStderrToOutPut];

  //hide cmd window toggle
  if cmd = 0 then AProcess.ShowWindow := swoHIDE;

  //run
  AProcess.Execute;

  //end process
  AProcess.Free;

  //stop procedure if closing while running
  if closeprogint=1 then exit;

end;

procedure TMainForm.btnSCheckClick(Sender: TObject);   //single run in thread
var CheckThread : TCheckThread;
begin
 closeprogint:=0; //reverses a cancel

 btnShowLog.Visible := false;
 btnOpendir.Visible := false;
 btnCLRscrClick(self);

 //open single file
 with dlgOpenSingleF do begin
    Options:=Options+[ofPathMustExist,ofFileMustExist];
    Filter:='All files (*.*)|*.*';
 end;

 //get info
 if dlgOpenSingleF.Execute then
 begin
   singlefile := dlgOpenSingleF.FileName;
   cbbFType1.Text := Copy(ExtractFileExt(dlgOpenSingleF.FileName),2,Length(ExtractFileExt(dlgOpenSingleF.FileName)));
   chosenDirectory := ExtractFilePath(dlgOpenSingleF.FileName);

   if Application.MessageBox(PChar('Do you want to check "' + singlefile +'"?'),'Media Check Pro', MB_ICONQUESTION + MB_YESNO) = IDYES then
   begin
        mainrunning:=1;
        btnCancel.Visible := true;
        //run code
        CheckThread := TCheckThread.Create(True); // This way it doesn't start automatically
        {Here the code initialises anything required before the threads starts executing}
        CheckThread.MultiFile:=0;
        CheckThread.Start;
   end
   else
   begin
         Application.MessageBox('Check Canceled','Media Check Pro',MB_ICONWARNING + MB_OK);
   end;

 end;

end;

procedure TMainForm.btnSConvertClick(Sender: TObject); //single convert in thread
var
  ConvertThread : TConvertThread;
begin
 closeprogint:=0; //reverses a cancel

 btnShowLog.Visible := false;
 btnOpendir.Visible := false;
 btnCLRscrClick(self);

 //open single file
 with dlgOpenSingleF do begin
    Options:=Options+[ofPathMustExist,ofFileMustExist];
    Filter:='All files (*.*)|*.*';
 end;

 //get info
 if dlgOpenSingleF.Execute then
 begin
   singlefile := dlgOpenSingleF.FileName;
   cbbFType1.Text := Copy(ExtractFileExt(dlgOpenSingleF.FileName),2,Length(ExtractFileExt(dlgOpenSingleF.FileName)));
   chosenDirectory := ExtractFilePath(dlgOpenSingleF.FileName);

   if Application.MessageBox(PChar('Do you want to convert "' + singlefile +'" to .' + cbbFType2.Text +'?'),'Media Check Pro', MB_ICONQUESTION + MB_YESNO) = IDYES then
   begin
        mainrunning:=1;
        btnCancel.Visible := true;
        //run code
        ConvertThread := TConvertThread.Create(True); // This way it doesn't start automatically
        {Here the code initialises anything required before the threads starts executing}
        ConvertThread.MultiFile:=0;
        ConvertThread.Start;
   end
   else
   begin
         Application.MessageBox('Conversion Canceled','Media Check Pro',MB_ICONWARNING + MB_OK);
   end;

 end;

end;

procedure TMainForm.btnBCheckClick(Sender: TObject);  //bulk check in thread
var CheckThread : TCheckThread;
begin
    closeprogint:=0; //reverses a cancel

    btnShowLog.Visible := false;
    btnOpendir.Visible := false;
    btnCLRscrClick(self);

    if SelectDirectory('Select Media Directory', '', chosenDirectory) then
    begin
      if Application.MessageBox(PChar('Do you want to check ".' + cbbFType1.text + '"''s in "' + chosenDirectory +'"?'),'Media Check Pro', MB_ICONQUESTION + MB_YESNO) = IDYES then
        begin
          mainrunning:=1;
          btnCancel.Visible := true;
          CheckThread := TCheckThread.Create(True); // This way it doesn't start automatically
          {Here the code initialises anything required before the threads starts executing}
          CheckThread.MultiFile:=1;
          CheckThread.Start;
          pbWorking.Style:=pbstMarquee;
          end
        else
        begin
          Application.MessageBox('Check Canceled','Media Check Pro',MB_ICONWARNING + MB_OK);
        end;
    end;
end;

procedure TMainForm.btnBConvertClick(Sender: TObject);  //bulk convert
var
   ConvertThread : TConvertThread;
begin
     closeprogint:=0; //reverses a cancel

     btnShowLog.Visible := false;
     btnOpendir.Visible := false;
     btnCLRscrClick(self);

    if SelectDirectory('Select Media Directory', '', chosenDirectory) then
    begin
      if Application.MessageBox(PChar('Do you want to convert all .' + cbbFType1.text + ' files to .' + cbbFType2.text + ' in "' + chosenDirectory +'"?'),'Media Check Pro', MB_ICONQUESTION + MB_YESNO) = IDYES then
      begin
        mainrunning:=1;
        btnCancel.Visible := true;
        ConvertThread := TConvertThread.Create(True); // This way it doesn't start automatically
        {Here the code initialises anything required before the threads starts executing}
        ConvertThread.MultiFile:=1;
        ConvertThread.Start;
        pbWorking.Style:=pbstMarquee;
      end
      else
      begin
         Application.MessageBox('Conversion Canceled','Media Check Pro',MB_ICONWARNING + MB_OK);
      end;
  end;
end;

procedure TMainForm.btnCancelClick(Sender: TObject);
begin
 latecan:=1;
 //if ffmpeg is running
 if ffmpegrun = 1 then
 begin
      closeprogint:=1; //stop further code execution on 2nd thread
      KillTask(timedatestr+'_ffmpeg.exe'); //kill ffmpeg exe
 end;

 //rename ffmpeg back to ori
 if FileExists(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe') then
 begin
      RenameFile(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe',ffmpeglocation+'/ffmpeg.exe');
 end;

end;

procedure TMainForm.FormCreate(Sender: TObject);  //on create
var
  Loadtype1,Loadtype2, LoadEL, LoadFT, LoadCMDs, LoadPN, LoadCSTR, LoadGPU: TStringList;
  i,j:integer;
begin
   //set var
   mainrunning:=0;

   closeprogint:=0;
   ffmpegrun:=0;
   ffmpeglocation:=ExtractFilePath(Application.ExeName);

   strlistCMDs:=TStringList.Create;


   //hide clr button
   btnCLRscr.Visible := false;
   btnOpendir.Visible := false;
   btnShowLog.Visible := false;
   btnCancel.Visible := false;

   //hide Progress Bar
   pbWorking.Style:=pbstNormal;


   //load pref files
   Loadtype1 := TStringList.Create;
   try
     Loadtype1.LoadFromFile('mtype.xmcpcontent');
     filetype1 := Loadtype1[0];
     cbbFType1.Text :=  filetype1;
   finally
     Loadtype1.Free;
   end;

   Loadtype2 := TStringList.Create;
   try
     Loadtype2.LoadFromFile('mtype2.xmcpcontent');
     filetype2 := Loadtype2[0];
     cbbFType2.Text :=  filetype2;
   finally
     Loadtype2.Free;
   end;

   LoadEL := TStringList.Create;
   try
     LoadEL.LoadFromFile('el.xmcpcontent');
     ErrorLevel := StrToInt(LoadEL[0]);
     cbbErrorLevel.ItemIndex := ErrorLevel;
   finally
     LoadEL.Free;
   end;

   LoadFT := TStringList.Create;
   try
     LoadFT.LoadFromFile('ft.xmcpcontent');
     SetLength(FileTypes,LoadFT.Count);

     for i := 0 to LoadFT.Count-1 do
     begin
       FileTypes[i]:=LoadFT[i];
       cbbFType1.Items.Add(LoadFT[i]);
       cbbFType2.Items.Add(LoadFT[i]);
     end;
     cbbFType1.Items.Insert(0,'* (All Files)');

   finally
     LoadFT.Free;
   end;

   LoadCMDs := TStringList.Create;
   try
     LoadCMDs.LoadFromFile('cmds.xmcpcontent');
     SetLength(FFMpegCMDs,LoadCMDs.Count div 2,2);

     for i := 0 to (LoadCMDs.Count div 2)-1 do
     begin
       j := i*2;
       FFMpegCMDs[i,0]:=LoadCMDs[j];
       FFMpegCMDs[i,1]:=LoadCMDs[j+1];
     end;
     //update preset CMD's
     updatepresetlist;
   finally
     LoadCMDs.Free;
   end;

   LoadPN := TStringList.Create;
   try
     LoadPN.LoadFromFile('pn.xmcpcontent');
     FormatNo := StrToInt(LoadPN[0]);
     cbbFormat.ItemIndex := FormatNo;
   finally
     LoadPN.Free;
   end;

   LoadGPU := TStringList.Create;
   try
     try
        LoadGPU.LoadFromFile('gpu.xmcpcontent');
        GPUacc := StrToInt(LoadGPU[0]);
     except
           on E: Exception do
           GPUacc := 0;
     end;
   finally
     if GPUacc = 1 then
     miGPU.Caption:='Disable NVIDIA GPU Acceleration'
     else
     miGPU.Caption:='Enable NVIDIA GPU Acceleration';
     LoadPN.Free;
   end;

   LoadCSTR := TStringList.Create;
   try
     LoadCSTR.LoadFromFile('cstr.xmcpcontent');
     AdvString := LoadCSTR[0];
     txtAdv.Text := AdvString;
   finally
     LoadCSTR.Free;
   end;

   //write memo
   mmoDisplay.Lines.Clear;
   mmoDisplay.Lines.Add('Welcome to Media Check Pro.');
   mmoDisplay.Lines.Add('');

   //check FFMPEG
   if CheckFFMPEG then application.Terminate;

end;

procedure TMainForm.FormClose(Sender: TObject); //on close
begin
  //save prefs
  if length(cbbFType1.Text) = 0 then
  filetype1 := 'Ori File Type'
  else
  filetype1 := cbbFType1.Text;

  if length(cbbFType2.Text) = 0 then
  filetype2 := 'New File Type'
  else
  filetype2 := cbbFType2.Text;

  if length(txtAdv.Text) = 0 then
  AdvString := ' '
  else
  AdvString := txtAdv.Text;

  ErrorLevel := cbbErrorLevel.ItemIndex;
  FormatNo :=  cbbFormat.ItemIndex;
  savefiles;

  //if ffmpeg is running
  if ffmpegrun = 1 then
  begin
       closeprogint:=1; //stop further code execution on 2nd thread
       KillTask(timedatestr+'_ffmpeg.exe'); //kill ffmpeg exe
  end;

  //rename ffmpeg back to ori
  if FileExists(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe') then
  begin
    RenameFile(ffmpeglocation+'/'+timedatestr+'_ffmpeg.exe',ffmpeglocation+'/ffmpeg.exe');
  end;

end;


end.

