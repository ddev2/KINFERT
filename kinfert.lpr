{$I Defines.pas}
program KinFert;

uses
	{$IFDEF UNIX}
	cthreads,
	{$ENDIF}
	Interfaces, // this includes the LCL widgetset
	Dialogs, sysutils, Forms, tachartlazaruspkg, Declarations, LazMain, LazConfig,
        LazOutput, ComponentHelper, LazGraph, LazUtiles, LazLowlevel, DocForm,
        LazKinSelection, Lazkinoutputfields, LazDemoCareFields, LazKinHeirSet, LazKinDecedentSet;

{$R *.res}
var
	temp: longint = 0;

begin
{$if declared(useHeapTrace)}
	globalSkipIfNoLeaks := true;
	if FileExists('heapTrace.log') then
		DeleteFile('heapTrace.log');
	setHeapTraceOutput('heapTrace.log');
	HaltOnError := False;
	GlobalSkipIfNoLeaks := True;
{$endIf}
	RequireDerivedFormResource:=True;
  Application.Title:='KinFert';
  Application.Scaled:=True;
	Application.Initialize;
	Application.CreateForm(TKinFertForm, KinFertForm);
	KinFertForm.Left := 0;
	KinFertForm.Top := 0;

	Application.CreateForm(TConfigForm, ConfigForm);
	ConfigForm.Left := 0;
	ConfigForm.Top := 0;
	Application.CreateForm(TLowLevelForm, LowLevelForm);
	LowLevelForm.Left := 0;
	LowLevelForm.Top := 0;
	LowLevelForm.Width := 495;
	LowLevelForm.Height := 580;
	Application.CreateForm(TOutputForm, OutputForm);
	OutputForm.Left := 0;
	OutputForm.Top := 0;
	Application.CreateForm(TUtilesForm, UtilesForm);
	UtilesForm.Left := 0;
	UtilesForm.Top := 0;
	Application.CreateForm(TGraphsForm, GraphsForm);
	GraphsForm.Left := 0;
	GraphsForm.Top := 0;
	Application.CreateForm(TDocumentation, Documentation);
	Documentation.Left := 0;
	Documentation.Top := 0;
	Documentation.Width := 872;
	Documentation.Height := 268;
        Application.CreateForm(TKinSelectionForm, KinSelectionForm);
  Application.CreateForm(TKinOutputFields, KinOutputFields);
  Application.CreateForm(TDemoCareFields, DemoCareFields);
  Application.CreateForm(THeirsSet, HeirsSet);
  Application.CreateForm(TDecedentsSet, DecedentsSet);
	Application.Run;
end.

