unit CustomProtocolFrm;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ExtCtrls, Vcl.StdCtrls,

  CommunicationFramework, PascalStrings,
  CommunicationFramework_Server_CrossSocket, CommunicationFramework_Client_CrossSocket,
  DoStatusIO, MemoryStream64, CoreClasses,

  IdBaseComponent, IdComponent, IdTCPConnection, IdTCPClient, IdGlobal;

type
  // TPeerClientUserSpecial��ÿ���ͻ���p2p���Ӻ������ʵ���ӿ�
  // ����Ҳ����ͨ���̳�TPeerClientUserDefine�ﵽͬ���Ĺ���
  TMyPeerClientUserSpecial = class(TPeerClientUserSpecial)
  public
    myBuffer: TMemoryStream64;

    constructor Create(AOwner: TPeerClient); override;
    destructor Destroy; override;

    // ������ͬ���¼��������ڴ˴�ʵ�ֶԵ���д�����Ƭ����������������
    procedure Progress; override;
  end;

  TMyServer = class(TCommunicationFramework_Server_CrossSocket)
  public
    // �ӷ�������ȡ�ⲿ���ƻ������������ӿ�
    // �����bufferȫ������Ƭ��������
    procedure OnReceiveBuffer(Sender: TPeerIO; const buffer: PByte; const Size: NativeInt); override;
  end;

  TMyClient = class(TCommunicationFramework_Client_CrossSocket)
  public
    myBuffer: TMemoryStream64;

    constructor Create; override;
    destructor Destroy; override;
    // �ӷ�������ȡ�ⲿ���ƻ������������ӿ�
    // �����bufferȫ������Ƭ��������
    procedure OnReceiveBuffer(const buffer: PByte; const Size: NativeInt); override;
  end;

  TCustomProtocolForm = class(TForm)
    Memo: TMemo;
    Timer: TTimer;
    Panel1: TPanel;
    connectOnIndyButton: TButton;
    SendDataOnIndyButton: TButton;
    IdTCPClient1: TIdTCPClient;
    connectOnZServerButton: TButton;
    SendDataOnZServerButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure connectOnIndyButtonClick(Sender: TObject);
    procedure connectOnZServerButtonClick(Sender: TObject);
    procedure SendDataOnIndyButtonClick(Sender: TObject);
    procedure TimerTimer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SendDataOnZServerButtonClick(Sender: TObject);
  private
  public
    // �Զ���Э��ķ�����
    myServer: TMyServer;

    // �Զ���Э��Ŀͻ���
    myClient: TMyClient;

    procedure DoStatusMethod(AText: SystemString; const ID: Integer);
  end;

var
  CustomProtocolForm: TCustomProtocolForm;

implementation

{$R *.dfm}


constructor TMyPeerClientUserSpecial.Create(AOwner: TPeerClient);
begin
  inherited;
  myBuffer := TMemoryStream64.Create;

end;

destructor TMyPeerClientUserSpecial.Destroy;
begin
  DisposeObject(myBuffer);

  inherited;
end;

procedure TMyPeerClientUserSpecial.Progress;
begin
  inherited;
  // ������ͬ���¼��������ڴ˴�ʵ�ֶԵ���д�����Ƭ����������������

  // �ȼ�黺�����ǲ��ǿ�
  if myBuffer.Size > 0 then
    begin
      // ������������ǿ�
      // ���Ǵ�ӡ���յ���������
      DoStatus(format('receive [%s] [%d] ', [Owner.PeerIP, Owner.ID]), myBuffer.Memory, myBuffer.Size, 16);
      // ���ǽ����յ�������ԭ�ⲻ���ķ��������ͷ�
      Owner.WriteCustomBuffer(myBuffer.Memory, myBuffer.Size);

      // ��ջ�������Ϊ��һ�δ�����׼��
      myBuffer.Clear;
    end;
end;

procedure TMyServer.OnReceiveBuffer(Sender: TPeerIO; const buffer: PByte; const Size: NativeInt);
begin
  // �ӷ�������ȡ�ⲿ���ƻ������������ӿ�
  // �����bufferȫ������Ƭ��������
  // ���ǽ���Ƭ������׷��д�뵽myBuffer
  TMyPeerClientUserSpecial(Sender.UserSpecial).myBuffer.WritePtr(buffer, Size);
end;

constructor TMyClient.Create;
begin
  inherited Create;
  myBuffer := TMemoryStream64.Create;
end;

destructor TMyClient.Destroy;
begin
  DisposeObject(myBuffer);
  inherited Destroy;
end;

procedure TMyClient.OnReceiveBuffer(const buffer: PByte; const Size: NativeInt);
begin
  // �ӷ�������ȡ�ⲿ���ƻ������������ӿ�
  // �����bufferȫ������Ƭ��������
  // ���ǽ���Ƭ������׷��д�뵽myBuffer
  myBuffer.WritePtr(buffer, Size);
end;

procedure TCustomProtocolForm.connectOnIndyButtonClick(Sender: TObject);
begin
  IdTCPClient1.Connect;

  if IdTCPClient1.Connected then
      DoStatus('connect on indy ok!');
end;

procedure TCustomProtocolForm.connectOnZServerButtonClick(Sender: TObject);
begin
  myClient.AsyncConnectP('127.0.0.1', 9989, procedure(const cState: Boolean)
    begin
      if cState then
          DoStatus('ZServer�Զ���ͻ������ӳɹ�');
    end);
end;

procedure TCustomProtocolForm.DoStatusMethod(AText: SystemString; const ID: Integer);
begin
  Memo.Lines.Add(AText);
end;

procedure TCustomProtocolForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  DisposeObject(myServer);
  DisposeObject(myClient);
end;

procedure TCustomProtocolForm.FormCreate(Sender: TObject);
begin
  AddDoStatusHook(Self, DoStatusMethod);
  myServer := TMyServer.Create;
  // ʹ���Զ���ͨѶЭ��
  myServer.Protocol := cpCustom;
  // ָ���ͻ��˵�p2pʵ���ӿ�
  myServer.PeerClientUserSpecialClass := TMyPeerClientUserSpecial;
  myServer.StartService('', 9989);

  myClient := TMyClient.Create;
  myClient.Protocol := cpCustom;
end;

procedure TCustomProtocolForm.TimerTimer(Sender: TObject);
var
  iBuf: TIdBytes;
begin
  myServer.Progress;
  myClient.Progress;

  if IdTCPClient1.Connected then
    begin
      // ������Է������ķ���
      if IdTCPClient1.IOHandler.InputBuffer.Size > 0 then
        begin
          // �������յ����������Ǵ�ӡ�������ķ���
          IdTCPClient1.IOHandler.InputBuffer.ExtractToBytes(iBuf);
          IdTCPClient1.IOHandler.InputBuffer.Clear;
          DoStatus(format('response ', []), @iBuf[0], length(iBuf), 16);
        end;
    end;

  if myClient.Connected then
    begin
      if myClient.myBuffer.Size > 0 then
        begin
          DoStatus(format('response ', []), myClient.myBuffer.Memory, myClient.myBuffer.Size, 16);
          myClient.myBuffer.Clear;
        end;
    end;
end;

procedure TCustomProtocolForm.SendDataOnIndyButtonClick(Sender: TObject);
var
  d: UInt64;
begin
  d := ($ABCDEF1234567890);
  // ������indy�ӿ�������������һ��uint����
  IdTCPClient1.IOHandler.WriteBufferOpen;
  // ����Ҫע��һ��:�����ת��������indyʹ�õĴ���ֽ����ת��(����indy�汾Ϊ�˼��ݷ�intel�ܹ������)�����ԣ�����Ҫ�ر�ת��
  IdTCPClient1.IOHandler.Write(d, False);
  IdTCPClient1.IOHandler.WriteBufferFlush;
  IdTCPClient1.IOHandler.WriteBufferClose;
end;

procedure TCustomProtocolForm.SendDataOnZServerButtonClick(Sender: TObject);
var
  d: UInt64;
begin
  d := ($ABCDEF1234567890);
  myClient.WriteBuffer(@d, SizeOf(d));
end;

end.