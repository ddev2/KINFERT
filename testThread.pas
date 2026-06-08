{$I Defines.pas}
unit testThreads;
//{$mode objfpc}{$H+}
interface
uses
{$IFDEF UNIX}
	cthreads,
{$ENDIF}
{$IFDEF UNIX_CMEM}
	{$if not declared(UseHeapTrace)}cmem,{$ifend}
{$ENDIF}
	Classes, SysUtils, Math;

procedure testThread();

implementation

type
  TData = array of double;
  PData = ^TData;
 Type
    TMyThread = class(TThread)
    private
    protected
      tPtr: PData;
      tstart,tfinish: integer;
      procedure Execute; override;
    public
      property Terminated;
      Constructor Create(lstart, lfinish: integer; var lPtr: PData);
    end;

  constructor TMyThread.Create(lstart, lfinish: integer; var lPtr: PData);
  begin
    FreeOnTerminate := False;
    tstart := lstart;
    tfinish := lfinish;
    tPtr := lPtr;
    inherited Create(false);
  end;
  procedure TMyThread.Execute;
  var
    i: integer;
  begin
    i:= tstart;
    While not Terminated and (i<= tfinish) do 
    //A well behaved thread in a loop should regularly check for termination 
        begin
    //for i := tstart to tfinish do
        tPtr^[i] := power(i,0.5);
        inc(i);
        end;
    Terminate;
  end;

procedure DoUnThreaded (nValues: integer);
var
 dataArray: TData;
 i: integer;
 StartMS: double;
begin
     if (nValues < 1) then exit;
     StartMS:=timestamptomsecs(datetimetotimestamp(now));
     setlength(dataArray, nValues+1);//+1 since indexed 0..n-1
     for i:=1 to nValues do
         dataArray[i] := power(i,0.5);  ;
     memoWriteLn(['Serially processed '+inttostr(nValues)+' values in '+floattostr(timestamptomsecs(datetimetotimestamp(now))-StartMS)+'ms, with '+inttostr(nValues)+'^0.5 = '+floattostr(dataArray[nValues])]);
end;

procedure DoThreading (nThreadsIn, nValues: integer);
var
 threadArray: array  of TMyThread;
 dataArray: TData;
 lData : PData;
 nThreads, i,lStart,lFinish: integer;
 StartMS: double;
begin
     if (nThreadsIn < 1) or (nValues < 1) then exit;
     nThreads := nThreadsIn;
     if  nThreads > nValues then nThreads := nValues;
     StartMS:=timestamptomsecs(datetimetotimestamp(now));
     setlength(threadArray,nThreads+1);//+1 since indexed 0..n-1
     setlength(dataArray, nValues+1);//+1 since indexed 0..n-1
     lData := @dataArray;
     lStart := 1;
     for i:=1 to nThreads do begin
         if i < nThreads then
            lFinish:=i*(nValues div nThreads)
         else
             lFinish:=  nValues;
         threadArray[i]:= TMyThread.Create(lStart, lFinish, lData);
         //Writeln('Thread '+inttostr(i)+' processing '+inttostr(lStart)+'..'+inttostr(lFinish));
         lStart := lFinish+1;
     end;
     //for i:=1 to nThreads do if not ThreadArray[i].Terminated then Sleep(2); Logically Wrong just introduces nx2ms delay
     //for i:=1 to nThreads do threadArray[i].waitFor;  //appears to sleep for 100ms on macOS

     for i:=1 to nThreads do 
        While not ThreadArray[i].Terminated do Sleep(2);   //do not progress until all threads have terminated 
 
     for i:=1 to nThreads do threadArray[i].Free; //Free not complete until the Thread Execute process exits.
     memoWriteLn([inttostr(nThreads)+' Threads processed '+inttostr(nValues)+' values in '+floattostr(timestamptomsecs(datetimetotimestamp(now))-StartMS)+'ms, with '+inttostr(nValues)+'^0.5 = '+floattostr(dataArray[nValues])]);

end;

procedure testThread();
begin
  memoWriteLn(['Computer reports '+inttostr(GetLogicalCpuCount)+' cores: probably optimal number of threads ']);
  DoUnthreaded(10);
  DoThreading(1,10);
  DoThreading(2,10);
  DoThreading(4,10);
  DoThreading(8,10);
  DoUnthreaded(100000000);
  DoThreading(1,100000000);
  DoThreading(2,100000000);
  DoThreading(4,100000000);
  DoThreading(8,100000000);
end;
end.
