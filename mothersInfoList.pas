        TMotherMemoryBlock = class
        public
          id: longint;
          cohort: longint;
          marStates: MarriagesType;
          ageChildren: TabCompFertAge;
          pChildrenList: pInfoChildType;
          Constructor Create(idMother, cohortMother: longint; ms: MarriagesType; ac: TabCompFertAge; pCh: pInfoChildType);
          Destructor Destroy(); override;
        end;

        TMotherInfo = class
        public
          info: TMotherMemoryBlock;
          numRef: longint;

            Constructor Create(idMother, cohortMother: longint; ms: MarriagesType; ac: TabCompFertAge; pCh: pInfoChildType);
            Destructor Destroy(); override;
            procedure addRef;
            function deleteRef: boolean;
            procedure ReleaseBlock(releaseChildren: boolean);
            function blockReleased: boolean;
            procedure assignMother (var ms: MarriagesType; var ac: TabCompFertAge; var pCh: pInfoChildType);
       end;

       TLinkedListMothers = class
         idMother: longint;
         next: TLinkedListMothers;
         Constructor Create(id: longint; stack: TLinkedListMothers);
         Destructor Destroy; override;
         procedure DestroyAll();
       end;

        TListMotherInfo = class
          nTotMothers, nTotMotherReleased: longint;
          mothers: array of TMotherInfo;
          motherStacks: array [FecundAges] of TLinkedListMothers;
          public
            Constructor Create();
            Destructor Destroy(); override;
            procedure addMotherToLIFOStack (var stack: TLinkedListMothers; id: longint);
            procedure keepMother (cohortMother, nbChildren: longint; ms: MarriagesType; ac: TabCompFertAge; pCh: pInfoChildType);
            function motherFound (ageMother: longint;
                                                            var ms: MarriagesType;
     							    var ac: TabCompFertAge;
     							    var pCh: pInfoChildType): boolean;
        end;

       Constructor TMotherMemoryBlock.Create(idMother, cohortMother: longint; ms: MarriagesType; ac: TabCompFertAge; pCh: pInfoChildType);
       begin
               id := idMother;
               cohort := cohortMother;
               marStates := ms;
               ageChildren := ac;
               pChildrenList := duplicateChildrenList (pCh);
       end;

        Destructor TMotherMemoryBlock.Destroy;
        begin
                if pChildrenList <> nil then disposeChild (pChildrenList);
                inherited Destroy;
        end;

        Constructor TMotherInfo.Create(idMother, cohortMother: longint; ms: MarriagesType; ac: TabCompFertAge; pCh: pInfoChildType);
        begin
                info := TMotherMemoryBlock.Create(idMother, cohortMother, ms, ac, pCh);
                numRef := 0;
        end;

        Destructor TMotherInfo.Destroy;
        begin
                if not blockReleased then ReleaseBlock(true);
                inherited Destroy;
        end;

        procedure TMotherInfo.addRef;
        begin
                numRef := numRef + 1;
        end;

        function TMotherInfo.deleteRef: boolean;
        begin
                numRef := numRef - 1;
                // if deleteRef is true, then this object should be freed
                deleteRef := (numRef = 0);
        end;

        procedure TMotherInfo.ReleaseBlock(releaseChildren: boolean);
        begin
                if not releaseChildren then
                  // Children list is used and released elsewhere, so we don't free it
                  info.pChildrenList := nil;
                freeAndNil (info);
        end;

        function TMotherInfo.blockReleased: boolean;
        begin
                blockReleased := info = nil;
        end;

        procedure TMotherInfo.assignMother (var ms: MarriagesType;
                                                        var ac: TabCompFertAge;
                                                        var pCh: pInfoChildType);
        begin
{$IFDEF DEBUG}
if info = nil then
  info := info;
{$ENDIF}
                ms := info.marStates;
                ac := info.ageChildren;
                pCh := info.pChildrenList;
                releaseBlock (false);
        end;

         Constructor TLinkedListMothers.Create(id: longint; stack: TLinkedListMothers);
         begin
                 idMother := id;
                 next:= stack;
         end;

         Destructor TLinkedListMothers.Destroy;
         begin
                 inherited Destroy;
         end;

        procedure TLinkedListMothers.DestroyAll();
        begin
                if next <> nil then next.DestroyAll;
                Self.Destroy;
        end;

        Constructor TListMotherInfo.Create;
        var
          ageFecund: FecundAges;
        begin
                nTotMothers := 0;
                nTotMotherReleased := 0;
                SetLength (mothers, kSetLengthMothers);

                for ageFecund := low(FecundAges) to high(FecundAges) do begin
                    motherStacks[ageFecund] := nil;
                end;
        end;

       Destructor TListMotherInfo.Destroy;
         var
          ageFecund: FecundAges;
          ind: longint;
       begin
               for ageFecund := low(FecundAges) to high(FecundAges) do begin
                       if motherStacks[ageFecund] <> nil then motherStacks[ageFecund].DestroyAll;
               end;
               for ind := 0 to high(mothers)-1 do begin
                   if mothers[ind] <> nil then
                     freeAndNil (mothers[ind]);
               end;
               SetLength (mothers, 0);

               inherited Destroy;
       end;

       procedure TListMotherInfo.addMotherToLIFOStack (var stack: TLinkedListMothers; id: longint);
       begin
               stack := TLinkedListMothers.Create(id, stack);
               mothers[id].addRef;
       end;

       procedure TListMotherInfo.keepMother (cohortMother, nbChildren: longint; ms: MarriagesType; ac: TabCompFertAge; pCh: pInfoChildType);
       var
           aMother: TMotherInfo;
           ageFecund: FecundAges;
        begin
              exit;

              if nbChildren = 0 then exit;
              nTotMothers := nTotMothers + 1;
              aMother := TMotherInfo.Create(nTotMothers, cohortMother, ms, ac, pCh);
              if nTotMothers > high(mothers) then
                 SetLength(mothers, high(mothers) + kSetLengthMothers);
              mothers[nTotMothers-1] := aMother;
              for ageFecund := low(FecundAges) to high(FecundAges) do begin
                  if ac[ageFecund, 0] > 0 then begin
                      addMotherToLIFOStack (motherStacks[ageFecund], nTotMothers-1);
                  end;
              end;
       end;

       function TListMotherInfo.motherFound (ageMother: longint;
                                        var ms: MarriagesType;
                                        var ac: TabCompFertAge;
                                        var pCh: pInfoChildType): boolean;
       var
           topStack: TLinkedListMothers;

       procedure cleanStack;
       begin
               while (topStack <> nil) and mothers[topStack.idMother].blockReleased do begin
                   if mothers[topStack.idMother].deleteRef then
                   begin
                       freeAndNil (mothers[topStack.idMother]);
                   end;
                   motherStacks [ageMother] := topStack.next;
                   freeAndNil (topStack);
                   topStack := motherStacks [ageMother];
               end;
       end;

       begin
            result := false;
            exit;

            topStack := motherStacks [ageMother];
            cleanStack;
            if topStack <> nil then begin
                result := true;
                mothers[topStack.idMother].assignMother(ms, ac, pCh);
                nTotMotherReleased := nTotMotherReleased + 1;
                cleanStack;
            end;
       end;

