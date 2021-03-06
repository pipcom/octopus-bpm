unit Octopus.Process;

interface

uses
  System.SysUtils,
  Generics.Collections,
  System.Rtti,
  Octopus.DataTypes;

type
  TWorkflowProcess = class;
  TFlowNode = class;
  TTransition = class;
  TVariable = class;
  TToken = class;
  TExecutionContext = class;
  TValidationContext = class;

  TEvaluateProc = reference to function(Context: TExecutionContext): boolean;

  Persistent = class(TCustomAttribute)
  private
    FPropName: string;
  public
    constructor Create(APropName: string = '');
    property PropName: string read FPropName;
  end;

  TWorkflowProcess = class
  private
    [Persistent]
    FNodes: TObjectList<TFlowNode>;
    [Persistent]
    FTransitions: TObjectList<TTransition>;
    [Persistent]
    FVariables: TObjectList<TVariable>;
  public
    constructor Create;
    destructor Destroy; override;
    function StartNode: TFlowNode;
    function GetNode(AId: string): TFlowNode;
    function GetTransition(AId: string): TTransition;
    function GetVariable(AName: string): TVariable;
    property Nodes: TObjectList<TFlowNode> read FNodes;
    property Transitions: TObjectList<TTransition> read FTransitions;
    property Variables: TObjectList<TVariable> read FVariables;
  end;

  TFlowElement = class
  private
    FId: string;
  public
    constructor Create; virtual;
    procedure Validate(Context: TValidationContext); virtual; abstract;
    [Persistent]
    property Id: string read FId write FId;
  end;

  IProcessInstanceData = interface
    procedure AddToken(Node: TFlowNode); overload;
    procedure AddToken(Transition: TTransition); overload;
    function CountTokens: integer;
    function GetTokens: TArray<TToken>; overload;
    function GetTokens(Node: TFlowNode): TArray<TToken>; overload;
    procedure RemoveToken(Token: TToken);
    function LastToken(Node: TFlowNode): TToken;
    function GetVariable(Name: string): TValue;
    procedure SetVariable(Name: string; Value: TValue);
    function GetLocalVariable(Token: TToken; Name: string): TValue;
    procedure SetLocalVariable(Token: TToken; Name: string; Value: TValue);
  end;

  TFlowNode = class abstract(TFlowElement)
  private
    FIncomingTransitions: TList<TTransition>;
    FOutgoingTransitions: TList<TTransition>;
  protected
    procedure ScanTransitions(Proc: TProc<TTransition>);
    procedure ExecuteAllTokens(Context: TExecutionContext; Flow: boolean);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Execute(Context: TExecutionContext); virtual; abstract;
    procedure Validate(Context: TValidationContext); override;
    procedure EnumTransitions(Process: TWorkflowProcess);
    function IsStart: boolean; virtual;
    property IncomingTransitions: TList<TTransition> read FIncomingTransitions;
    property OutgoingTransitions: TList<TTransition> read FOutgoingTransitions;
  end;

  TTransition = class(TFlowElement)
  private
    [Persistent]
    FSource: TFlowNode;
    [Persistent]
    FTarget: TFlowNode;
    FEvaluateProc: TEvaluateProc;
  public
    procedure Validate(Context: TValidationContext); override;
    function Evaluate(Context: TExecutionContext): boolean; virtual;
    procedure SetCondition(AProc: TEvaluateProc);
    property Source: TFlowNode read FSource write FSource;
    property Target: TFlowNode read FTarget write FTarget;
  end;

  TVariable = class
  private
    FName: string;
    FDataType: TOctopusDataType;
    FDefaultValue: TValue;
    procedure SetDefaultValue(const Value: TValue);
    function GetDataTypeName: string;
    procedure SetDataTypeName(const Value: string);
  public
    destructor Destroy; override;
    [Persistent]
    property Name: string read FName write FName;
    property DataType: TOctopusDataType read FDataType write FDataType;
    [Persistent('Type')]
    property DataTypeName: string read GetDataTypeName write SetDataTypeName;
    [Persistent]
    property DefaultValue: TValue read FDefaultValue write SetDefaultValue;
  end;

  TToken = class
  private
    FTransition: TTransition;
    FNode: TFlowNode;
    function GetNode: TFlowNode;
    procedure SetNode(const Value: TFlowNode);
    procedure SetTransition(const Value: TTransition);
  public
    property Transition: TTransition read FTransition write SetTransition;
    property Node: TFlowNode read GetNode write SetNode;
  end;

  TExecutionContext = class
  private
    FInstance: IProcessInstanceData;
    FProcess: TWorkflowProcess;
    FNode: TFlowNode;
    FPersistedTokens: TList<TToken>;
    FError: boolean;
  public
    constructor Create(AInstance: IProcessInstanceData; AProcess: TWorkflowProcess; ANode: TFlowNode; APersistedTokens: TList<TToken>);
    function GetIncomingToken: TToken; overload;
    function GetIncomingToken(Transition: TTransition): TToken; overload;
    function LastData(Variable: string): TValue; overload;
    function LastData(ANode: TFlowNode; Variable: string): TValue; overload;
    function LastData(NodeId, Variable: string): TValue; overload;
    procedure PersistToken(Token: TToken);
    property Instance: IProcessInstanceData read FInstance;
    property Process: TWorkflowProcess read FProcess;
    property Node: TFlowNode read FNode;
    property Error: boolean read FError write FError;
  end;

  TValidationResult = class
  private
    FElement: TFlowElement;
    FError: boolean;
    FMessage: string;
  public
    constructor Create(AElement: TFlowElement; AError: boolean; AMessage: string);
    property Element: TFlowElement read FElement;
    property Error: boolean read FError;
    property Message: string read FMessage;
  end;

  TValidationContext = class
  private
    FResults: TList<TValidationResult>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddError(AElement: TFlowElement; AMessage: string);
    property Results: TList<TValidationResult> read FResults;
  end;

implementation

uses
  Octopus.Global,
  Octopus.Resources;

{ TWorkflowProcess }

constructor TWorkflowProcess.Create;
begin
  FNodes := TObjectList<TFlowNode>.Create;
  FTransitions := TObjectList<TTransition>.Create;
  FVariables := TObjectList<TVariable>.Create;
end;

destructor TWorkflowProcess.Destroy;
begin
  FNodes.Free;
  FTransitions.Free;
  FVariables.Free;
  inherited;
end;

function TWorkflowProcess.GetNode(AId: string): TFlowNode;
begin
  for result in Nodes do
    if SameText(AId, result.Id) then
      exit;
  result := nil;
end;

function TWorkflowProcess.GetTransition(AId: string): TTransition;
begin
  for result in Transitions do
    if SameText(AId, result.Id) then
      exit;
  result := nil;
end;

function TWorkflowProcess.GetVariable(AName: string): TVariable;
begin
  for result in Variables do
    if SameText(AName, result.Name) then
      exit;
  result := nil;
end;

function TWorkflowProcess.StartNode: TFlowNode;
begin
  for result in Nodes do
    if result.IsStart then
      exit;
  result := nil;
end;

{ TFlowNode }

constructor TFlowNode.Create;
begin
  inherited;
  FIncomingTransitions := TList<TTransition>.Create;
  FOutgoingTransitions := TList<TTransition>.Create;
end;

destructor TFlowNode.Destroy;
begin
  FIncomingTransitions.Free;
  FOutgoingTransitions.Free;
  inherited;
end;

procedure TFlowNode.EnumTransitions(Process: TWorkflowProcess);
var
  Transition: TTransition;
begin
  FIncomingTransitions.Clear;
  FOutgoingTransitions.Clear;
  for Transition in Process.Transitions do
  begin
    if Transition.Target = Self then
      FIncomingTransitions.Add(Transition);
    if Transition.Source = Self then
      FOutgoingTransitions.Add(Transition);
  end;
end;

procedure TFlowNode.ExecuteAllTokens(Context: TExecutionContext; Flow: boolean);
var
  token: TToken;
begin
  token := Context.GetIncomingToken;
  while token <> nil do
  begin
    if Flow then
    begin
      Context.Instance.RemoveToken(token);

      ScanTransitions(
        procedure(Transition: TTransition)
        begin
          if Transition.Evaluate(Context) then
            Context.Instance.AddToken(Transition);
        end);
    end
    else
      Context.PersistToken(token);

    token := Context.GetIncomingToken;
  end;
end;

function TFlowNode.IsStart: boolean;
begin
  result := false;
end;

procedure TFlowNode.ScanTransitions(Proc: TProc<TTransition>);
var
  Transition: TTransition;
begin
  // scan the outgoing Transitions from a node and execute the callback procedure for each one
  for Transition in OutgoingTransitions do
    Proc(Transition);
end;

procedure TFlowNode.Validate(Context: TValidationContext);
begin
  if IncomingTransitions.Count = 0 then
    Context.AddError(Self, SErrorNoIncomingTransition);
end;

{ TToken }

function TToken.GetNode: TFlowNode;
begin
  if Transition <> nil then
    result := Transition.Target
  else
    result := FNode;
end;

procedure TToken.SetNode(const Value: TFlowNode);
begin
  FNode := Value;
  FTransition := nil;
end;

procedure TToken.SetTransition(const Value: TTransition);
begin
  FTransition := Value;
  FNode := nil;
end;

{ TTransition }

function TTransition.Evaluate(Context: TExecutionContext): boolean;
begin
  if Assigned(FEvaluateProc) then
    result := FEvaluateProc(Context)
  else // TODO: condition expression?
    result := true;
end;

procedure TTransition.SetCondition(AProc: TEvaluateProc);
begin
  FEvaluateProc := AProc;
end;

procedure TTransition.Validate(Context: TValidationContext);
begin
  if Source = nil then
    Context.AddError(Self, SErrorNoSourceNode);
  if Target = nil then
    Context.AddError(Self, SErrorNoTargetNode);
end;

{ TExecutionContext }

constructor TExecutionContext.Create(AInstance: IProcessInstanceData; AProcess: TWorkflowProcess; ANode: TFlowNode; APersistedTokens: TList<TToken>);
begin
  FInstance := AInstance;
  FProcess := AProcess;
  FNode := ANode;
  FPersistedTokens := APersistedTokens;
  FError := false;
end;

function TExecutionContext.GetIncomingToken: TToken;
var
  token: TToken;
begin
  for token in FInstance.GetTokens(Node) do
    if not FPersistedTokens.Contains(token) then
      exit(token);
  result := nil;
end;

function TExecutionContext.LastData(ANode: TFlowNode; Variable: string): TValue;
var
  token: TToken;
begin
  token := Instance.LastToken(ANode);
  if token <> nil then
    result := Instance.GetLocalVariable(Token, Variable)
  else
    result := TValue.Empty;
end;

function TExecutionContext.LastData(NodeId, Variable: string): TValue;
begin
  result := LastData(Process.GetNode(NodeId), Variable);
end;

procedure TExecutionContext.PersistToken(Token: TToken);
begin
  FPersistedTokens.Add(Token);
end;

function TExecutionContext.GetIncomingToken(Transition: TTransition): TToken;
var
  token: TToken;
begin
  for token in FInstance.GetTokens(Node) do
    if not FPersistedTokens.Contains(token) and (token.Transition = Transition) then
      exit(token);
  result := nil;
end;

function TExecutionContext.LastData(Variable: string): TValue;
begin
  result := LastData(Node, Variable);
end;

{ TValidationResult }

constructor TValidationResult.Create(AElement: TFlowElement; AError: boolean; AMessage: string);
begin
  FElement := AElement;
  FError := AError;
  FMessage := AMessage;
end;

{ TValidationContext }

procedure TValidationContext.AddError(AElement: TFlowElement; AMessage: string);
begin
  FResults.Add(TValidationResult.Create(AElement, true, AMessage));
end;

constructor TValidationContext.Create;
begin
  FResults := TObjectList<TValidationResult>.Create;
end;

destructor TValidationContext.Destroy;
begin
  FResults.Free;
  inherited;
end;

{ TVariable }

destructor TVariable.Destroy;
begin
  if not FDefaultValue.IsEmpty and FDefaultValue.IsObject then
    FDefaultValue.AsObject.Free;
  inherited;
end;

function TVariable.GetDataTypeName: string;
begin
  if DataType <> nil then
    result := DataType.Name
  else
    result := '';
end;

procedure TVariable.SetDataTypeName(const Value: string);
begin
  if Value <> '' then
    DataType := TOctopusDataTypes.Default.Get(Value)
  else
    DataType := nil;
end;

procedure TVariable.SetDefaultValue(const Value: TValue);
begin
  FDefaultValue := Value;
  if (FDataType = nil) and not FDefaultValue.IsEmpty then
    FDataType := TOctopusDataTypes.Default.Get(Value.TypeInfo);
end;

{ TFlowElement }

constructor TFlowElement.Create;
begin
  FId := TUtils.NewId;
end;

{ Persistent }

constructor Persistent.Create(APropName: string);
begin
  FPropName := APropName;
end;

end.

