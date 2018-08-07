unit Dv.CleanDProj;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.Variants,
  Winapi.Windows,
  XML.XMLIntf,
  XML.XMLDoc,
  XML.XMLDom;

procedure DoCleanDproj(AFileName: string); overload;
procedure DoCleanDproj(AStream: TStream); overload;
procedure SortNodes(ANodes: IXMLNodeList);

implementation

function NodeHasAllAttrs(ANode: IXMLNode; ASearchNode: IXMLNode): Boolean;
var
  I: Integer;
  AAttrNode: IXMLNode;
  AAttrName: string;
begin
  Result := True;
  for I := 0 to ASearchNode.AttributeNodes.Count - 1 do
  begin
    AAttrName := ASearchNode.AttributeNodes[I].NodeName;
    AAttrNode := ANode.AttributeNodes.FindNode(ASearchNode.AttributeNodes[I].NodeName);
    if (AAttrNode = nil) or (AAttrNode.Text <> ASearchNode.AttributeNodes[I].Text) then
      Exit(False);
  end;
end;

// From a post in Embarcadero's Delphi XML forum.
function SelectNode(xnRoot: IXmlNode; const nodePath: WideString): IXmlNode;
var
  intfSelect : IDomNodeSelect;
  dnResult : IDomNode;
  intfDocAccess : IXmlDocumentAccess;
  doc: TXmlDocument;
begin
  Result := nil;
  if not Assigned(xnRoot) or not Supports(xnRoot.DOMNode, IDomNodeSelect, intfSelect) then
    Exit;
  dnResult := intfSelect.selectNode(nodePath);
  if Assigned(dnResult) then
  begin
    if Supports(xnRoot.OwnerDocument, IXmlDocumentAccess, intfDocAccess) then
      doc := intfDocAccess.DocumentObject
    else
      doc := nil;
    Result := TXmlNode.Create(dnResult, nil, doc);
  end;
end;

function FindOrAddNode(AParent: IXMLNode; ATagName: string): IXMLNode;
begin
  Result := AParent.ChildNodes.FindNode(ATagName);
  if Result = nil then
    Result := AParent.AddChild(ATagName);
end;

function NodeListToArray(ANodes: IXMLNodeList): TArray<IXMLNode>;
var
  I: Integer;
begin
  SetLength(Result, ANodes.Count);
  for I := 0 to ANodes.Count - 1 do
    Result[I] := ANodes.Get(I);
end;

function ForceVarToStr(AValue: Variant): string;
begin
  if AValue = Null then
    Result := ''
  else
    Result := AValue;
end;

function CompareXMLNode(const Left, Right: IXMLNode): Integer;
var
  ALeftAttrs, ARightAttrs: TArray<IXMLNode>;
  I: Integer;
begin
  if Left = Right then
    Exit(0);
  // Compare tag
  Result := CompareStr(Left.Prefix + Left.NodeName, Right.Prefix + Right.NodeName);
  // Compare attributes
  if Result = 0 then
  begin
    ALeftAttrs := NodeListToArray(Left.AttributeNodes);
    ARightAttrs := NodeListToArray(Right.AttributeNodes);
    for I := Low(ALeftAttrs) to High(ALeftAttrs) do
    begin
      if I > High(ARightAttrs) then
        Result := 1;
      if Result <> 0 then
        Break;
      Result := CompareStr(ALeftAttrs[I].NodeName, ARightAttrs[I].NodeName);
      if Result <> 0 then
        Break;
      Result := CompareText(ForceVarToStr(ALeftAttrs[I].NodeValue), ForceVarToStr(ARightAttrs[I].NodeValue));
      if Result <> 0 then
        Break;
    end;
    if (Result = 0) and (High(ALeftAttrs) > High(ARightAttrs)) then
      Result := -1;
  end;
  // Compare full XML
  if Result = 0 then
    Result := CompareStr(Left.XML, Right.XML);
  // Compare index in parent
  if (Result = 0) and (Left.ParentNode <> nil) and (Right.ParentNode <> nil) then
    Result := Left.ParentNode.ChildNodes.IndexOf(Left) - Right.ParentNode.ChildNodes.IndexOf(Right);
end;

procedure SortNodes(ANodes: IXMLNodeList);
var
  ANodeArray: TArray<IXMLNode>;
  I: Integer;
begin
  if ANodes.Count = 0 then
    Exit;
  SetLength(ANodeArray, ANodes.Count);
  for I := 0 to ANodes.Count - 1 do
  begin
    SortNodes(ANodes.Nodes[I].ChildNodes);
    ANodeArray[I] := ANodes.Nodes[I];
  end;
  TArray.Sort<IXMLNode>(ANodeArray, TComparer<IXMLNode>.Construct(CompareXMLNode));
  ANodes.Clear;
  for I := 0 to Length(ANodeArray) - 1 do
    ANodes.Add(ANodeArray[I]);
end;

procedure DoCleanDproj(AFileName: string); overload;
var
  AStream: TStream;
begin
  AStream := TFileStream.Create(AFileName, fmOpenReadWrite);
  try
    DoCleanDproj(AStream);
  finally
    AStream.Free;
  end;
end;

procedure DoCleanDproj(AStream: TStream);
var
  ADocument: IXMLDocument;
  AByteOrderMark: TBytes; // BOM
  ANode: IXMLNode;
  AStreamReader: TStreamReader;
  AStreamWriter: TStreamWriter;
  AStringBuilder: TStringBuilder;
begin
  ADocument := NewXMLDocument;
  // Import
  ADocument.NodeIndentStr := '    ';
  ADocument.Options := [doNodeAutoCreate, doAttrNull, doAutoPrefix, doNamespaceDecl];
  ADocument.ParseOptions := [];
  ADocument.LoadFromStream(AStream, xetUTF_8);
  // Set sensible error options
  //ASearchNode := ADocument.CreateNode('Project', ntElement);
  //ASearchNode.AddChild('PropertyGroup').Attributes['Condition'] := '''$(Base)''!=''''';
  ANode := SelectNode(ADocument.DocumentElement, '//*[local-name()=''PropertyGroup''][@Condition="''$(Base)''!=''''"]');
  if ANode <> nil then
  begin
    FindOrAddNode(ANode, 'DCC_USE_BEFORE_DEF').Text := 'error';
    FindOrAddNode(ANode, 'DCC_NO_RETVAL').Text := 'error';
    SortNodes(ANode.ChildNodes);
  end;
  // Sort the shit
  ANode := SelectNode(ADocument.DocumentElement, '//*[local-name()=''ProjectExtensions'']/*[local-name()=''BorlandProject'']/*[local-name()=''Deployment'']');
  if ANode <> nil then
    SortNodes(ANode.ChildNodes);
  ANode := SelectNode(ADocument.DocumentElement, '//*[local-name()=''Project'']/*[local-name()=''ItemGroup'']');
  if ANode <> nil then
    SortNodes(ANode.ChildNodes);
  // Reset file
  AStream.Position := 0;
  AStream.Size := 0;
  // Reset build config
  ANode := SelectNode(ADocument.DocumentElement, '//*[local-name()=''Project'']/*[local-name()=''PropertyGroup'']/*[local-name()=''Config'']');
  if ANode <> nil then
    ANode.Text := 'Release';
  AStringBuilder := TStringBuilder.Create;
  try
    // Save the xml
    ADocument.SaveToStream(AStream);
    // Replace tabs for spaces
    AStreamReader := TStreamReader.Create(AStream, True);
    try
      AStream.Position := 0;
      AStringBuilder.Append(AStreamReader.ReadToEnd);
    finally
      AStreamReader.Free;
    end;
    AStringBuilder.Replace(#9, '    ');

    AStreamWriter := TStreamWriter.Create(AStream, TEncoding.UTF8);
    try
      // Reset file
      AStream.Position := 0;
      AStream.Size := 0;
      // Write an encoding byte-order mark and buffer to output file.
      AByteOrderMark := TUTF8Encoding.UTF8.GetPreamble;
      AStream.Write(AByteOrderMark[0], Length(AByteOrderMark));
      // Remove lines
      AStreamWriter.Write(AStringBuilder.ToString);
    finally
      AStreamWriter.Free;
    end;
  finally
    AStringBuilder.Free;
  end;
end;

end.
