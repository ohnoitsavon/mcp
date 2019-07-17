unit Unit2;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls, lclintf,
  ExtCtrls;

type

  { TfrmAbout }

  TfrmAbout = class(TForm)
    imgMCP: TImage;
    lblk1: TLabel;
    lblM: TLabel;
    lblInfo: TLabel;
    lblN2: TLabel;
    lblO1: TLabel;
    lblMtee: TLabel;
    lblFFMPEG: TLabel;
    lblAbout: TLabel;
    lblN1: TLabel;
    lblI1: TLabel;
    lblA1: TLabel;
    procedure lblA1Click(Sender: TObject);
    procedure lblI1Click(Sender: TObject);
    procedure lblk1Click(Sender: TObject);
    procedure lblMClick(Sender: TObject);
    procedure lblMteeClick(Sender: TObject);
    procedure lblFFMPEGClick(Sender: TObject);
    procedure lblN1Click(Sender: TObject);
    procedure lblO1Click(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  frmAbout: TfrmAbout;
  strcyhm: string;

implementation

{$R *.lfm}

{ TfrmAbout }



procedure TfrmAbout.lblFFMPEGClick(Sender: TObject);
begin
  OpenURL('https://ffmpeg.zeranoe.com/builds/');
end;

procedure TfrmAbout.lblN1Click(Sender: TObject);
begin
   strcyhm:=strcyhm+'n';
end;

procedure TfrmAbout.lblO1Click(Sender: TObject);
begin
  strcyhm:=strcyhm+'o';
end;

procedure TfrmAbout.lblMteeClick(Sender: TObject);
begin
  OpenURL('https://ritchielawrence.github.io/mtee/ ');
end;

procedure TfrmAbout.lblMClick(Sender: TObject);
begin
  strcyhm:='m'
end;

procedure TfrmAbout.lblI1Click(Sender: TObject);
begin
  strcyhm:=strcyhm+'i';
end;

procedure TfrmAbout.lblA1Click(Sender: TObject);
begin
  strcyhm:=strcyhm+'a';
  if strcyhm.length > 3 then
  begin
       if strcyhm = 'monika' then
       showmessage('Hi '+GetEnvironmentVariable('USERNAME')+'! Can you hear me?')
       else
       begin
         showmessage('Nice try!');
         strcyhm:=''
       end;
  end;

end;

procedure TfrmAbout.lblk1Click(Sender: TObject);
begin
  strcyhm:=strcyhm+'k';
end;

end.

