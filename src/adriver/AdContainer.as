package adriver
{
	import adriver.events.AdriverEvent;

	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.AsyncErrorEvent;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.text.TextField;
	import flash.utils.Timer;

	// if you don't want to use vkontakte libraries, comment it out and
	// in parameters, supply an external real Button
	import vkontakte.vk.ui.VKButton;

	public class AdContainer extends MovieClip
	{

		private var shift = 60;
		private var defW = 128;
		private var loadedBanners = [];
		private var count:Number = 0;
		private var res:Array = [];
		private var params:Object = [];

		private var videoURL:String;
		private var connection:NetConnection;
		private var stream:NetStream;

		private var parameters:Object;

		private var _parent:Object;
		private var _video_url:String;
		private var _click_url:String;
		private var _event_url:String;

		private var scenario_obj:Object;

		private var durationText:TextField;

		private var duration_timer:Timer;
		private var skip_timer:Timer;

		private var loaders:Object = [];
		private var wnd:Sprite;
		public var isAdMount:Boolean;
		public var skip_button;
		private var iSWF:Boolean = false;
		private var video:Video;
		private var loader:Loader;
		
		public function AdContainer(given_parameters:Object, mc)
		{
			super();
			parameters = given_parameters;
			_parent = mc;
			
			buttonMode = true;
		}

		private function onSkipTimer(event:TimerEvent):void {
			skip_button.removeEventListener(MouseEvent.CLICK, onSkipClickEmpty);
			skip_button.addEventListener(MouseEvent.CLICK, onSkipClick);
			skip_button.enabled = true;
		}

		private function show_duration():void
		{
			skip_button.label = parameters.skip_button_label + " (" + parameters.max_duration+")";

			duration_timer = new Timer(1000, parameters.max_duration);
			duration_timer.addEventListener(TimerEvent.TIMER, onTick);
			duration_timer.addEventListener(TimerEvent.TIMER_COMPLETE, onAdTimerComplete);
			duration_timer.start();
		}

		private function onTick(event:TimerEvent):void
		{
			var i:int = parameters.max_duration - event.target.currentCount;
			skip_button.label = parameters.skip_button_label + " (" + i+")";
		}

		private function onAdTimerComplete(event:TimerEvent):void
		{
			if (stream) {
				stream.close();
			}

			clean_container();
			sendEvent(AdriverEvent.LIMITED);

			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.LIMITED));
		}

		public function clean_container():void
		{
			if(parameters.max_duration && parameters.max_duration > 0) {
				duration_timer.removeEventListener(TimerEvent.TIMER, onTick);
				duration_timer.removeEventListener(TimerEvent.TIMER_COMPLETE, onAdTimerComplete);
			}

			if (parameters.skip_button_timeout) {
				skip_timer.removeEventListener(TimerEvent.TIMER, onSkipTimer);
			}

			if (stream) {
				stream.close();
			}

			for each (var obj:DisplayObject in loaders) {
				this.removeChild(obj);
			}

			if (skip_button) {
				skip_button.removeEventListener(MouseEvent.CLICK, onSkipClick);
				removeChild(skip_button);
			}

			isAdMount = false;
		}
		
		private function prepare_container(aWidth:int, aHeight:int, iVideo=false):void
		{
			if (!iVideo){
				this.width = aWidth;
				this.height = aHeight;
			}
			
			if (iSWF) {
				var rect:Shape = new Shape(); 
				rect.graphics.beginFill(0xFFFFFF); 
				rect.graphics.drawRect(0, 0, aWidth, aHeight); 
				addChild(rect); 
				loader.mask = rect;
			}
			
			if (typeof(parameters.skip_button) != "object" && (parameters.skip_button == true)) {
				parameters.debug("AD: making our own VKButton");

				// can be commented out if you don't want vkbuttons
				skip_button = new VKButton(parameters.skip_button_label);
				skip_button.x = (aWidth + skip_button.width/2)/this.scaleX;
				
				//skip_button.x = aWidth - skip_button.width;
				//skip_button.y = aHeight - skip_button.height;

				addChild(skip_button);
				setChildIndex(skip_button, numChildren-1);
			}
			else if (typeof(parameters.skip_button) == "object") {
				// our own skip button
				parameters.debug("AD: using external Button");
				skip_button = parameters.skip_button;
				
				trace("Csize", this.width, this.height)
				
				skip_button.x = this.width/2 - skip_button.width/2;
				skip_button.y = this.height + 10;
				
				
				if (skip_button.y > (parameters.style.height - skip_button.height - 10)) {
					skip_button.y = parameters.style.height - skip_button.height - 10;
				}
				
				addChild(skip_button);
				setChildIndex(skip_button, numChildren-1);
			}
			
			if (skip_button){
				if (parameters.skip_button_timeout) {
					parameters.debug("AD: skip button has timeout");
					skip_button.enabled = false;
					skip_timer = new Timer(parameters.skip_button_timeout*1000, 1);
					skip_timer.addEventListener(TimerEvent.TIMER, onSkipTimer);
					skip_timer.start();
					
					skip_button.addEventListener(MouseEvent.CLICK, onSkipClickEmpty);
				}
				else{
					skip_button.addEventListener(MouseEvent.CLICK, onSkipClick);
				}
				
				if (parameters.max_duration > 0) {
					show_duration();
				}
			}

			isAdMount = true;
		}
		
		
		
		
		
		public function loadBanner(url:String, x:int, y:int, isSWF:Boolean=false):void
		{
			iSWF = isSWF;
			
			parameters.debug("AD: Loading banner");
			loader = new Loader();
			
			configureListeners(loader.contentLoaderInfo);
			var request:URLRequest = new URLRequest(url);
			loader.load(request);
			addChild(loader);
			loaders.push(loader);
			sendEvent(AdriverEvent.STARTED);
			this.dispatchEvent(new AdriverEvent(AdriverEvent.LOADED));
		}

		private function connectStream():void
		{
			stream = new NetStream(connection);
			stream.client = new Object();
			stream.client.onMetaData = function(obj) {
				parameters.debug("AD: video size: width="+obj.width + ", height="+obj.height);
				
				if (obj.width > (parameters.style.width - 60)) {
					obj.width = parameters.style.width - 60;
				}
				var was_width:int = video.width; 
				var scaleFactor:Number = video.width/was_width;
				video.width = obj.width;
				video.height = obj.height * scaleFactor;
				
				
				prepare_container(obj.width, obj.height, true);
				dispatchEvent(new AdriverEvent(AdriverEvent.LOADED));
				_parent.dispatchEvent(new AdriverEvent(AdriverEvent.LOADED));
			}
			stream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
			video = new Video();
			video.attachNetStream(stream);
			stream.play(_video_url);
			addChild(video);
			loaders.push(video);
		}
		
		private function onSkipClickEmpty(event:MouseEvent):void 
		{
			event.stopPropagation();
		}
		
		private function onSkipClick(event:MouseEvent):void
		{
			removeEventListener(MouseEvent.CLICK, _parent.onAdClick);
			parameters.debug("AD: Skip button clicked in container");
			clean_container();
			sendEvent(AdriverEvent.SKIPPED);
			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.SKIPPED));
		}
		
		private function configureListeners(dispatcher:IEventDispatcher):void
		{
			dispatcher.addEventListener(Event.COMPLETE, completeHandler);
			dispatcher.addEventListener(HTTPStatusEvent.HTTP_STATUS, httpStatusHandler);
			dispatcher.addEventListener(Event.INIT, initHandler);
			dispatcher.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
			dispatcher.addEventListener(Event.OPEN, openHandler);
			dispatcher.addEventListener(ProgressEvent.PROGRESS, progressHandler);
			dispatcher.addEventListener(Event.UNLOAD, unLoadHandler);
		}

		private function sendEvent(event:String):void
		{
			if (parameters.eventUrl) {
				var temp = function(e:Event):void {
					trace(e + '\n');
				}
				parameters.debug("AD: Logging adriver event: " +event);
				trace(parameters.eventUrl+AdriverEvent.getEventID(event));
				var request:URLRequest = new URLRequest(parameters.eventUrl+AdriverEvent.getEventID(event));
				var loader:URLLoader = new URLLoader();
				loader.addEventListener(IOErrorEvent.IO_ERROR, temp);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, temp);
				loader.load(request);
			}
		}

		private function completeHandler(event:Event):void
		{
			//trace("completeHandler: " + event + "\n");
			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.LOADED));
			prepare_container(event.target.width, event.target.height);
		}

		private function httpStatusHandler(event:HTTPStatusEvent):void
		{
			//trace("httpStatusHandler: " + event + "\n");
		}

		private function initHandler(event:Event):void
		{
			//trace("initHandler: " + event + "\n");
		}

		private function ioErrorHandler(event:IOErrorEvent):void
		{
			//trace("ioErrorHandler: " + event + "\n");
			clean_container();
			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
		}

		private function openHandler(event:Event):void
		{
			//trace("openHandler: " + event + "\n");
		}

		private function progressHandler(event:ProgressEvent):void
		{
			//trace("progressHandler: bytesLoaded=" + event.bytesLoaded + " bytesTotal=" + event.bytesTotal + "\n");
			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.PROGRESS));
		}

		private function unLoadHandler(event:Event):void
		{
			//trace("unLoadHandler: " + event + "\n");
		}

		public function showVideo(url:String):void
		{
			_video_url = url;
			connection = new NetConnection();
			connection.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			connection.addEventListener(SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler);
			connection.connect(null);
		}

		private function netStatusHandler(event:NetStatusEvent):void
		{
			parameters.debug("AD: ..net event: "+event.info.code);

			switch (event.info.code) {
				case "NetConnection.Connect.Success":
					parameters.debug("AD: ..video stream connect");
					connectStream();
					sendEvent(AdriverEvent.STARTED);
					break;
				case "NetStream.Play.StreamNotFound":
					parameters.debug("AD: ..Unable to locate video: " + _video_url);
					clean_container();
					sendEvent(AdriverEvent.FAILED);
					_parent.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
					break;
				case "NetStream.Play.Failed":
					parameters.debug("AD: Play failed: " + _video_url);
					clean_container();
					sendEvent(AdriverEvent.FAILED);
					_parent.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
				case "NetStream.Play.Stop":
					clean_container();
					parameters.debug("AD: Play finished: " + _video_url);
					sendEvent(AdriverEvent.FINISHED);
					_parent.dispatchEvent(new AdriverEvent(AdriverEvent.FINISHED));
//				default:
//					parameters.debug("AD: Play failed. Unknown event: " + event.info.code)
//					sendEvent(AdriverEvent.FAILED);
//					_parent.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
			}
		}

		private function securityErrorHandler(event:SecurityErrorEvent):void {
			parameters.debug("AD: securityErrorHandler: " + event);
			clean_container();
			sendEvent(AdriverEvent.FAILED);
			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
		}

		private function asyncErrorHandler(event:AsyncErrorEvent):void {
			parameters.debug("AD: securityAsyncErrorEvent: " + event);
		}
	}
}
