#include-once
#include <_HttpRequest.au3>
#include "AutoitObject_Internal.au3"

Global Const $cLink_FB = "https://mbasic.facebook.com/"
Global Const $cLink_FBFull = "https://www.facebook.com/"
Global Const $cLink_Login = "login/device-based/regular/login/"
Global Const $cLink_Post = "composer/mbasic/?av="
Global Const $cLink_Group = "groups/"
Global Const $cLink_React = "api/graphql/"
Global Const $cLink_Msg = "messages/send/"
Global Const $cLink_Unread = "api/graphqlbatch/"
Global Const $cLink_GetMsg = "api/graphqlbatch/"
Global Const $cLink_Friend = "friends/center/friends/"
Global Const $cLink_Groups = "groups/?seemore"

Global Const $c_Header = 1
Global Const $c_Html = 2

Global Const $PRIVACY_PUBLIC = "300645083384735"
Global Const $PRIVACY_FRIEND = "291667064279714"
Global Const $PRIVACY_ONLYME = "286958161406148"

Global Const $REACT_UNLIKE = 0
Global Const $REACT_LIKE = 1
Global Const $REACT_LOVE = 2
Global Const $REACT_WOW = 3
Global Const $REACT_HAHA = 4
Global Const $REACT_SAD = 7
Global Const $REACT_ANGRY = 8

Func Facebook($userName, $userPass = "")

	$isFromFile = FileExists($userName) ; if load from user & pass or from file
	If $userPass = False And $isFromFile = False Then Return False ; if neither, then return false

	If $isFromFile Then Return FB_LoadFromFile($userName)

	$hFB = __CreateFB($userName, $userPass)

	Return $hFB
EndFunc

Func FB_LoadFromFile($File)

	$userName = IniRead($File, "facebook", "user", -1)
	$userPass = IniRead($File, "facebook", "pass", -1)
	$name = __Decode( IniRead($File, "facebook", "name", -1) )
	$uid = IniRead($File, "facebook", "uid", -1)
	$dtsg = IniRead($File, "facebook", "dtsg", -1)
	$cookie = IniRead($File, "facebook", "cookie", -1)

	If $userName = -1 Or $userPass = -1 Or $name = -1 Or $uid = -1 Or $dtsg = -1 Or $cookie = -1 Then Return False

	; create facebook
	$hFB = __CreateFB($userName, $userPass, $name, $uid, $dtsg, $cookie)
	$hFB.isLogin = True

	; check if cookie is still useable, if not then login
	If __CheckAlive($cookie) = False Then $hFB.login()

	Return $hFB
EndFunc

Func FB_SaveToFile($this)

	If $this.arguments.length = 0 Then Return False

	$File = $this.arguments.values[0]
	$hFB = $this.parent

	FileDelete($File)
	IniWrite($File, "facebook", "user", $hFB.user)
	IniWrite($File, "facebook", "pass", $hFB.pass)
	IniWrite($File, "facebook", "name", __Encode( $hFB.name ))
	IniWrite($File, "facebook", "uid", $hFB.uid)
	IniWrite($File, "facebook", "dtsg", $hFB.dtsg)
	IniWrite($File, "facebook", "cookie", $hFB.cookie)

	Return True
EndFunc

Func FB_Login($this)

	$hFB = $this.parent
	If __CheckFB($hFB) = False Then Return False

	; assign variable
	$userName = $hFB.user
	$userPass = $hFB.pass

	; make a request to homepage to get cookie
	$Request = _HttpRequest($c_Html, $cLink_FB)
	$cookie = _GetCookie($Request)

	; username and password
	$loginData = __GetLoginPost($Request, $userName, $userPass)

	; login
	$Request = _HttpRequest($c_Html, $cLink_FB & $cLink_Login, $loginData, $cookie)
	$cookie = _GetCookie($Request)
	$name = __GetLoginName($Request)
	$dtsg = __GetLoginDTSG($Request)
	$uid = __GetUserID($cookie)

	; login failed
	If $uid = False Then
		$hFB.isLogin = False
		Return False
	EndIf

	; set data to hfb
	$hFB.name = $name
	$hFB.uid = $uid
	$hFB.dtsg = $dtsg
	$hFB.cookie = $cookie
	$hFB.isLogin = True

	Return True
EndFunc

Func FB_Post($this)

	If $this.arguments.length < 3 Then Return False

	$hFB = $this.parent
	$post = $this.arguments.values[0]
	$data = $this.arguments.values[1]
	$type = $this.arguments.values[2] ; 0 = profile post, 1 = group post, 2 = wall post

	If __CheckFB($hFB) = False Then Return False

	; if profile post then ? xxx else : xxx
	$dataPost = __GetDataPost($hFB.uid, $hFB.dtsg, $post, $data, $type)

	$Request = _HttpRequest($c_Html, $cLink_FB & $cLink_Post & $hFB.uid, $dataPost, $hFB.cookie)

	$PostID = __GetPostIDRecent($Request)

	If $PostID = False Then Return False

	Return $PostID
EndFunc

Func FB_PostGroup($this)

	If $this.arguments.length < 2 Then Return False

	$hFB = $this.parent

	; post( post_data, post_id, 1 = group post)
	$hFB.post( $this.arguments.values[0], $this.arguments.values[1], True)
EndFunc

Func FB_React($this)

	If $this.arguments.length = 0 Then Return False

	$hFB = $this.parent
	$PostID = $this.arguments.values[0]
	$React = $this.arguments.length = 0 ? $REACT_LIKE : $this.arguments.values[1]

	If __CheckFB($hFB) = False Then Return False

	$dataPost = __GetReactPost($hFB, $hFB, $PostID, $React)

	$Request = _HttpRequest($c_Html, $cLink_FBFull & $cLink_React, $dataPost, $hFB.cookie)

	; check if success
	If StringInStr($Request, "reaction_type") Then Return True
	Return False
EndFunc

; Author ~ Tuan Van Hoang Vo
Func FB_SendMsg($this)
	If $this.arguments.length = 0 Then Return False

	$hFB = $this.parent
	$sendID = $this.arguments.values[0]
	$Message = $this.arguments.values[1]
	If __CheckFB($hFB) = False Then Return False

	$dataPost = __GetMsgPost($hFB.dtsg, $Message, $sendID)
	$Request = _HttpRequest($c_Html, $cLink_FB & $cLink_Msg, $dataPost, $hFB.cookie)

	If StringInStr($Request, "messageGroup") = False Then Return False

	Return $Request
EndFunc

; Author ~ Tuan Van Hoang Vo
Func FB_getUnread($this)

	$hFB = $this.parent
	If __CheckFB($hFB) = False Then Return False

	$limit = $this.arguments.length = 0 ? 30 : $this.arguments.values[0] ; if no param then set to default (30)

	$dataPost = __GetUnreadMsgPost($hFB.dtsg, $limit)

	$Request = _HttpRequest($c_Html, $cLink_FBFull & $cLink_Unread, $dataPost, $hFB.cookie)
	$aData = __GetDataUnread($Request)

	If $aData = False Then Return False

	Return $aData
EndFunc

; Author ~ Tuan Van Hoang Vo
Func FB_GetMsg($this)
	If $this.arguments.length = 0 Then Return False

	$hFB = $this.parent
	$id = $this.arguments.values[0]
	$limit = $this.arguments.length < 2 ? 30 : $this.arguments.values[1] ; if no param then set to default (30)

	If __CheckFB($hFB) = False Then Return False

	$dataPost = __GetMsgDataPost($hFB.uid, $hFB.dtsg, $id, $limit)

	$Request = _HttpRequest($c_Html, $cLink_FBFull & $cLink_GetMsg, $dataPost, $hFB.cookie)

	$aMsg = __GetDataMsg($Request)

    If $aMsg = False Then Return False
	Return $aMsg
EndFunc

Func FB_GetAllFriends($this)

	$hFB = $this.parent
	If __CheckFB($hFB) = False Then Return False

	Local $aFriend[0][3], $url_base = $cLink_FB & $cLink_Friend

	For $index = 0 To 100000

		$url = $url_base & "?ppk=" & $index & "&bph=" & $index & "&tid=u_0_0"

		$Request = _HttpRequest($c_Html, $url, "", $hFB.cookie)
		$aData = __GetDataFriends($Request)

		If IsArray($aData) = False Then ExitLoop
		__ArrayAdd($aFriend, $aData)
	Next

	If UBound($aFriend) = 0 Then Return False

	Return $aFriend
EndFunc

Func FB_GetAllGroups($this)

	$hFB = $this.parent
	If __CheckFB($hFB) = False Then Return False

	$Request = _HttpRequest($c_Html, $cLink_FB & $cLink_Groups, "", $hFB.cookie)
	$aGroups = __GetDataGroups($Request)

	If $aGroups = False Then Return False
	Return $aGroups
EndFunc

Func _GetGroupID($url)

	$groupURL = StringSplit($url, "/", 1)
	If $groupURL[0] <= 1 Then Return False

	$groupURL = $groupURL[ $groupURL[0] - 1 ]
	$Request = _HttpRequest(2, $cLink_FB & $cLink_Group & $groupURL)

	$groupID = StringRegExp($Request, '<a href="\/groups\/(.*?)\?view', 1)

	If IsArray($groupID) = False Then Return False
	Return $groupID[0]

EndFunc

Func __CreateFB($userName, $userPass, $name = False, $uid = False, $dtsg = False, $cookie = False)

	Local $hFB = IDispatch()
	$hFB.user = $userName
	$hFB.pass = $userPass
	$hFB.name = $name ; name
	$hFB.uid = $uid ; user id
	$hFB.dtsg = $dtsg ; dtsg
	$hFB.cookie = $cookie ; cookie
	$hFB.isLogin = False

	$hFB.__defineGetter('login', FB_Login)
	$hFB.__defineGetter('post', FB_Post)
	$hFB.__defineGetter('postGroup', FB_PostGroup)
	$hFB.__defineGetter('react', FB_React)
	$hFB.__defineGetter('sendMsg', FB_SendMsg)
	$hFB.__defineGetter('getUnread', FB_getUnread)
	$hFB.__defineGetter('getMsg', FB_GetMsg)
	$hFB.__defineGetter('getAllFriends', FB_GetAllFriends)
	$hFB.__defineGetter('getAllGroups', FB_GetAllGroups)
	$hFB.__defineGetter('save', FB_SaveToFile)
	Return $hFB
EndFunc

Func __CheckFB($hFB)
	If IsObj($hFB) = False Or $hFB.user = False Or $hFB.pass = False Then Return False
	Return True
EndFunc

Func __CheckAlive($cookie)

	$Request = _HttpRequest($c_Html, $cLink_FB, "", $cookie)
	If StringInStr($Request, "m_newsfeed_stream") = False Then Return False

	Return True
EndFunc

Func __GetUserID($Cookie)

	$uid = StringRegExp($cookie, "c_user=(.*?);", 1)
	If IsArray($uid) = False Then Return False ; login failed

	Return $uid[0]
EndFunc

Func __GetLoginName($Request)

	$name = StringRegExp($Request, 'img src="(.*?)\>', 3)
	If IsArray($name) = False Then Return False

	$name = StringRegExp( $name[1], 'alt="(.*?)"', 1)
	If IsArray($name) = False Then Return False

	Return __Decode($name[0])
EndFunc

Func __GetLoginDTSG($Request)
	$dtsg = StringRegExp($Request, 'name="fb_dtsg" value="(.*?)"', 1)
	If IsArray($dtsg) = False Then Return False
	Return $dtsg[0]
EndFunc

Func __GetLoginPost($Request, $userName, $userPass)

	$lsd = StringRegExp($Request, 'name="lsd" value="(.*?)"', 1)
	$jazoest = StringRegExp($Request, 'name="jazoest" value="(.*?)"', 1)
	$m_ts = StringRegExp($Request, 'name="m_ts" value="(.*?)"', 1)
	$li = StringRegExp($Request, 'name="li" value="(.*?)"', 1)

	; check
	If IsArray($lsd) = False Or IsArray($jazoest) = False Or IsArray($m_ts) = False Or IsArray($li) = False Then Return False

	Return "lsd=" & $lsd[0] & "&jazoest=" & $jazoest[0] & "&m_ts=" & $m_ts[0] & "&li=" & $li[0] &"&try_number=0&unrecognized_tries=0&email=" & _URIEncode($userName) & "&pass=" & _URIEncode($userPass)
EndFunc

Func __GetDataPost($uid, $dtsg, $post, $data, $type)

	$dataPost = "fb_dtsg=" & _URIEncode($dtsg)

	Switch $type

		Case 0 ; profile post
			$dataPost &= "&privacyx=" & $data ; privacy
			$dataPost &= "&target=" & $uid
			$dataPost &= "&c_src=feed&referrer=feed"

		Case 1 ; group post
			$dataPost &= "&target="& $data ; group id
			$dataPost &= "&c_src=group&referrer=group"

		Case 1 ; wall post
			$dataPost &= "&id="& $data ; profile id
			$dataPost &= "&target="& $data ; profile id
			$dataPost &= "&c_src=timeline_other&referrer=timeline"
	EndSwitch

	$dataPost &= "&xc_message=" & _URIEncode($post)
	$dataPost &= "&view_post=%C4%90%C4%83ng"

	Return $dataPost
EndFunc

Func __GetReactPost($uid, $dtsg, $PostID, $React)

	$dataPost = "av={UID}&fb_dtsg={DTSG}&fb_api_req_friendly_name=UFI2FeedbackReactMutation&variables=%7B%22input%22%3A%7B%22client_mutation_id%22%3A%226%22%2C%22actor_id%22%3A%22{UID}%22%2C%22feedback_id%22%3A%22{POSTID}%22%2C%22feedback_reaction%22%3A{REACT}%7D%2C%22useDefaultActor%22%3Atrue%7D&doc_id=1853002534829264"
	$dataPost = StringReplace($dataPost, "{UID}", $uid)
	$dataPost = StringReplace($dataPost, "{DTSG}", _URIEncode($dtsg))
	$dataPost = StringReplace($dataPost, "{POSTID}", _B64Encode("feedback:" & $PostID))
	$dataPost = StringReplace($dataPost, "{REACT}", $React)

	Return $dataPost
EndFunc

Func __GetMsgPost($dtsg, $message, $id)

	$dataPost = "fb_dtsg=" & $dtsg
	$dataPost &= "&body=" & $message
	$dataPost &= "&ids%5B" & $id & "%5D=" & $id

	Return $dataPost
EndFunc

Func __GetUnreadMsgPost($dtsg, $limit)
	$dataPost = "fb_dtsg=" & $dtsg
	$dataPost &= '&batch_name=MessengerGraphQLThreadlistFetcher&queries={"o0":{"doc_id":"2227394360618999","query_params":'
	$dataPost &= '{"limit":' & $limit
	$dataPost &= ',"before":null,"tags":["INBOX"],"isWorkUser":false,"includeDeliveryReceipts":true,"includeSeqID":false}}}'

	Return _Data2SendEncode($dataPost)
EndFunc

Func __GetMsgDataPost($uid, $dtsg, $id, $limit)
	$dataPost ='__user=' & $uid
	$dataPost &= '&__a=1&fb_dtsg=' & $dtsg
	$dataPost &= '&queries={"o0":{"doc_id":"1630697047001937","query_params":{"id":"' & $id
	$dataPost &= '","message_limit":' & $limit
	$dataPost &= ',"load_messages":1,"load_read_receipts":true,"before":null}}}'

	Return _Data2SendEncode($dataPost)
EndFunc

Func __GetDataUnread($Request)

	$data = StringRegExp( _HTMLDecode($Request) , '"other_user_id":"(\d+)".*?"snippet":"(.*?)".".*?"messaging_actor":\{"id":"(\d+)".*?"unread_count":(\d+).*?"name":"(.*?)","gender":"(.*?)"', 3)
	If IsArray($data) = False  Then Return False

	For $i = 0 To UBound($data) - 1
		$data[$i] = _HTMLDecode($data[$i])
	Next

	Return $data
EndFunc

Func __GetDataFriends($Request)

	Local $aData[0][3]

	$friends = StringRegExp( _HTMLDecode($Request) , 'role="presentation"\>(.*?)\<\/table\>', 3)

	If IsArray($friends) = False Then Return False

	For $iFriend = 0 To UBound($friends) - 1
		$img = StringRegExp( $friends[$iFriend], '\<img src="(.*?)"', 1)
		$uid = StringRegExp( $friends[$iFriend], "uid=(.*?)\&", 1 )
		$name = StringRegExp( $friends[$iFriend], 'acted">(.*?)</a>', 1 )

		If IsArray($img) = False Or IsArray($uid) = False Or IsArray($name) = False Then ContinueLoop

		$index = UBound($aData)
		ReDim $aData[$index + 1][3]
		$aData[$index][0] = $uid[0]
		$aData[$index][1] = $name[0]
		$aData[$index][2] = $img[0]
	Next

	If UBound($aData) = 0 Then Return False

	Return $aData
EndFunc

Func __GetDataGroups($Request)

	Local $aData[0][3]

	$groups = StringRegExp( _HTMLDecode($Request) , 'role="presentation"\>(.*?)\<\/table\>', 3)

	If IsArray($groups) = False Then Return False

	For $iGroup = 0 To UBound($groups) - 1

		$groupID = StringRegExp( $groups[$iGroup], '\/groups\/([0-9]*?)\?', 1)
		$groupName = StringRegExp( $groups[$iGroup], '27">(.*?)<\/a>', 1)

		If IsArray($groupID) = False Then ContinueLoop

		$index = UBound($aData)
		ReDim $aData[$index + 1][3]
		$aData[$index][0] = $groupID[0]
		$aData[$index][1] = $groupName[0]
	Next

	If UBound($aData) = 0 Then Return False

	Return $aData
EndFunc

Func __GetDataMsg($Request)

	$data = StringRegExp(_HTMLDecode($Request), '"message_sender":\{"id":"(\d+)".*?"message":\{"text":"(.*?)","ranges"', 3)
	If IsArray($data) = False Then Return False

	Return $data
EndFunc

Func __GetPostIDRecent($Request)
	$id = StringRegExp($Request, "&quot;top_level_post_id&quot;:&quot;(.*?)&quot;", 1)
	If IsArray($id) = False Then Return False
	Return $id[0]
EndFunc

Func __ArrayAdd(ByRef $Array, $Add)

	$cur = UBound($Array)
	ReDim $Array[ $cur + UBound($Add) ][ UBound($Array, 2) ]

	For $iRow = $cur To UBound($Array) - 1

		For $iCol = 0 To UBound($Array, 2) - 1

			$Array[$iRow][$iCol] = $Add[$iRow - $cur][$iCol]
		Next
	Next

EndFunc

Func __Decode($str)

	$chars = StringRegExp($str, "&#x(.*?);", 3)
	If IsArray($chars) = False Then Return False

	For $iChr = 0 To UBound($chars) - 1
		If $chars[$iChr] = "" Then ContinueLoop
		$chr = ChrW( "0x" & $chars[$iChr] )
		$str = StringRegExpReplace($str, "&#x" & $chars[$iChr] & ";", $chr)
	Next

	Return $str
EndFunc

Func __Encode($str)

	$len = StringLen($str)

	For $i = $len To 1 Step - 1

		$chr = StringMid($str, $i, 1)
		$asc = Asc($chr)

		; if unicode
		If Chr($asc) = $chr Then ContinueLoop

		$str = StringReplace($str, $i, @LF)
		$str = StringReplace($str, @LF, "&#x" & Hex(AscW($chr), 4) & ";")
	Next

	Return $str
EndFunc