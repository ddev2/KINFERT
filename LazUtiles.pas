unit LazUtiles;

{$mode objfpc}{$H+}

interface

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
    Interfaces, // this includes the LCL widgetset
    Forms,
	Classes, SysUtils, Controls, Graphics, Dialogs, StdCtrls, strutils,
	Declarations, Kinship;

type

  { TUtilesForm }

  TUtilesForm = class(TForm)
	BACKFOR: TCheckBox;
	CAMSIM1987: TCheckBox;
	CAMSIM1993: TCheckBox;
	CAMSIM1993_AgeUnionUnbounded: TCheckBox;
	EgoValues: TEdit;
	Label3: TLabel;
	//NEW_INIT_MOTHERHOOD: TCheckBox;
	ToEgoValue: TEdit;
	FromEgoValue: TEdit;
	ViewGeoInfo: TGroupBox;
	Label1: TLabel;
	Label2: TLabel;
	RealBACKFOR: TCheckBox;
	DEBUG: TCheckBox;
	OKBtn: TButton;
	DemocareCheck: TButton;
	OpenDemocare: TOpenDialog;
	procedure BACKFORChange(Sender: TObject);
	procedure CAMSIM1987Change(Sender: TObject);
	procedure CAMSIM1993Change(Sender: TObject);
	procedure CAMSIM1993_AgeUnionUnboundedChange(Sender: TObject);
	procedure DEBUGChange(Sender: TObject);
	//procedure NEW_INIT_MOTHERHOODChange(Sender: TObject);
	procedure DemocareCheckClick(Sender: TObject);
	procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
	procedure FormCreate(Sender: TObject);
	procedure FormActivate(Sender: TObject);
	procedure OKBtnClick(Sender: TObject);
	procedure RealBACKFORChange(Sender: TObject);
  public
	function fromFamily: longint;
	function toFamily: longint;
  end;

var
  UtilesForm: TUtilesForm;

implementation

Uses LazMain;

{$R *.lfm}

{ TUtilesForm }

procedure TUtilesForm.DemocareCheckClick(Sender: TObject);
var
  s: ansistring;
  filename, path: string;
begin
  KinFertForm.ClearLog();
  s := 'Democare file|*.txt';
  OpenDemocare.Filter := s;
  OpenDemocare.Options := OpenDemocare.Options+[ofFileMustExist];
  if not OpenDemocare.Execute then exit;
  try
	filename := OpenDemocare.filename;
	path := ExtractFilePath(filename);
	filename := ExtractFileName(filename);

	if readDemocareFile (path, filename) then begin
	  ShowMessage ('File read. Results in main window');
	end else
	  ShowMessage ('Error while reading Democare file');
	KinFertForm.FlushString({%H-}PtrInt(nil));
 except
	on E: Exception do begin
	  MessageDlg('Error','Error: ' + E.Message,mtError,[mbOk],0);
	end;
  end

end;

procedure egoFamilies (text: string);
var
	n: longint;
  	A: TStringArray;
    s: string;
  	ind, x: longint;
begin
 	removetrailingchars(text,[#13,#10]);
	if length(text) > 0 then begin
		A := text.Split(',');
        n := length(A);
		if n > 0 then begin
			SetLength (gViewEgos, n);
			for ind := 1 to n do
                if length(A[ind-1]) > 0 then begin
                    s := A[ind-1];
                    x := strToInt(s);
                    gViewEgos[ind-1] := gViewEgos[ind-1];
					gViewEgos[ind-1] := x;
				end;
		end;
	end;
end;

procedure TUtilesForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
 CanClose := TRUE;
 gViewFromEgo := strToInt (TEdit (FindComponent ('FromEgoValue')).text);
 gViewToEgo := strToInt (TEdit (FindComponent ('ToEgoValue')).text);
 egoFamilies (TEdit (FindComponent ('EgoValues')).text);
end;

procedure TUtilesForm.BACKFORChange(Sender: TObject);
begin
 gBACKFOR_mode := BACKFOR.checked;
 if gBACKFOR_mode then begin
	RealBACKFOR.checked := FALSE;
	gBACKFOR_mode_pure := FALSE;
	CAMSIM1987.checked := FALSE;
	gCAMSIM_1987 := FALSE;
	CAMSIM1993.checked := FALSE;
	gCAMSIM_1993 := FALSE;
	CAMSIM1993_AgeUnionUnbounded.enabled := FALSE;
 end;
end;

procedure TUtilesForm.CAMSIM1987Change(Sender: TObject);
begin
 gCAMSIM_1987 := CAMSIM1987.checked;
 if gCAMSIM_1987 then begin
	gBACKFOR_mode_pure := FALSE;
	RealBACKFOR.checked := FALSE;
	BACKFOR.checked := FALSE;
	gBACKFOR_mode := FALSE;
	CAMSIM1993.checked := FALSE;
	gCAMSIM_1993 := FALSE;
	CAMSIM1993_AgeUnionUnbounded.enabled := FALSE;
 end;
end;

procedure TUtilesForm.CAMSIM1993Change(Sender: TObject);
begin
 gCAMSIM_1993 := CAMSIM1993.checked;
 CAMSIM1993_AgeUnionUnbounded.enabled := gCAMSIM_1993;
 if gCAMSIM_1993 then begin
	 gBACKFOR_mode_pure := FALSE;
	 RealBACKFOR.checked := FALSE;
	 BACKFOR.checked := FALSE;
	 gBACKFOR_mode := FALSE;
	 CAMSIM1987.checked := FALSE;
	 gCAMSIM_1987 := FALSE;
   end;
end;

procedure TUtilesForm.CAMSIM1993_AgeUnionUnboundedChange(Sender: TObject);
begin
 gCAMSIM_1993_unbounded := CAMSIM1993_AgeUnionUnbounded.checked;
end;

procedure TUtilesForm.DEBUGChange(Sender: TObject);
begin
 g_GENPARAM.DEBUG.value := DEBUG.checked;
 g_GENPARAM.DEBUG.changed := (g_GENPARAM.DEBUG.value <> g_GENPARAM.DEBUG.default);
end;

//procedure TUtilesForm.NEW_INIT_MOTHERHOODChange(Sender: TObject);
//begin
// g_GENPARAM.NEW_INIT_MOTHERHOOD.value := NEW_INIT_MOTHERHOOD.checked;
// g_GENPARAM.NEW_INIT_MOTHERHOOD.changed := (g_GENPARAM.NEW_INIT_MOTHERHOOD.value <> g_GENPARAM.NEW_INIT_MOTHERHOOD.default);
//end;

function convToStr (const a: array of longint): string;
var
	ind: longint;
begin
	result := '';
    if (length(a) = 0) then
    	exit ('0');
	if length (a) > 1 then begin
   		for ind := 0 to length (a)-2 do
   			result := result + IntToStr(a[ind]) + ',';
	end;
	result := result + IntToStr(a[length (a)-1]);
end;

procedure TUtilesForm.FormCreate(Sender: TObject);
begin
 OKBtn.Default := true;
 BACKFOR.checked := gBACKFOR_mode;
 RealBACKFOR.checked := gBACKFOR_mode_pure;
 CAMSIM1987.checked := gCAMSIM_1987;
 CAMSIM1993.checked := gCAMSIM_1993;
 CAMSIM1993_AgeUnionUnbounded.checked := gCAMSIM_1993_unbounded;
 CAMSIM1993_AgeUnionUnbounded.enabled := gCAMSIM_1993;
 DemocareCheck.Default := false;
 TEdit (FindComponent ('FromEgoValue')).text := IntToStr (gViewFromEgo);
 TEdit (FindComponent ('ToEgoValue')).text := IntToStr (gViewToEgo);
 TEdit (FindComponent ('EgoValues')).text := convToStr (gViewEgos);
end;

procedure TUtilesForm.FormActivate(Sender: TObject);
begin
 DEBUG.checked := g_GENPARAM.DEBUG.value;
 g_GENPARAM.DEBUG.changed := (g_GENPARAM.DEBUG.value <> g_GENPARAM.DEBUG.default);
// NEW_INIT_MOTHERHOOD.checked := g_GENPARAM.NEW_INIT_MOTHERHOOD.value;
// g_GENPARAM.NEW_INIT_MOTHERHOOD.changed := (g_GENPARAM.NEW_INIT_MOTHERHOOD.value <> g_GENPARAM.NEW_INIT_MOTHERHOOD.default);
end;

procedure TUtilesForm.OKBtnClick(Sender: TObject);
begin
  ModalResult := mrClose;
end;

procedure TUtilesForm.RealBACKFORChange(Sender: TObject);
begin
 gBACKFOR_mode_pure := RealBACKFOR.checked;
 if gBACKFOR_mode_pure then begin
	BACKFOR.checked := FALSE;
	gBACKFOR_mode := FALSE;
	CAMSIM1987.checked := FALSE;
	gCAMSIM_1987 := FALSE;
	CAMSIM1993.checked := FALSE;
	gCAMSIM_1993 := FALSE;
	CAMSIM1993_AgeUnionUnbounded.enabled := FALSE;
 end;
end;

function TUtilesForm.fromFamily: longint;
begin
 result := StrToInt (FromEgoValue.text);
end;

function TUtilesForm.toFamily: longint;
begin
 result := StrToInt (ToEgoValue.text);
end;

end.

