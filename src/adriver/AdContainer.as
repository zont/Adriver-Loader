package adriver
{
	import adriver.events.AdriverEvent;
	
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.MovieClip;
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
	import flash.external.ExternalInterface;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.text.TextField;
	import flash.ui.Mouse;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import vkontakte.vk.ui.VKButton;
	
	public class AdContainer extends MovieClip
	{
		
		private var shift = 60;
		private var defW = 128;
		private var loadedBanners = [];
		private var count:Number = 0;
		private var res:Array = [];
		private var params:Object = [];
		
		private var ad_links:Dictionary = new Dictionary();
		
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
		
		private var skip_button:VKButton;
		
		public var isAdMount:Boolean;
		
		public function AdContainer(given_parameters:Object, mc)
		{
			super();
			parameters = given_parameters;
			_parent = mc;
		}
		
		private function onSkipTimer(event:TimerEvent):void {
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
			if(parameters.max_duration > 0) {
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
			
			skip_button.removeEventListener(MouseEvent.CLICK, onSkipClick);
			
			if (parameters.skip_button) {
				removeChild(skip_button);
			}
			
			isAdMount = false;
		}
		
		private function prepare_container(aWidth:int, aHeight:int):void {
			
			if (parameters.skip_button) {
				
				skip_button = new VKButton(parameters.skip_button_label);
				
				
				skip_button.x = aWidth - skip_button.width;
				skip_button.y = aHeight - skip_button.height;
				
				addChild(skip_button);
				
				skip_button.addEventListener(MouseEvent.CLICK, onSkipClick);
				
				setChildIndex(skip_button, numChildren-1);
			}
			
			if (parameters.skip_button_timeout) {
				parameters.skip_button.enabled = false;
				skip_timer = new Timer(parameters.skip_button_timeout*1000, 1);
				skip_timer.addEventListener(TimerEvent.TIMER, onSkipTimer);
				skip_timer.start();				
			}
			
			if( parameters.max_duration > 0) {
				show_duration();
			}
			
			isAdMount = true;
		}
		
		private function onSkipClick(event:MouseEvent):void
		{
			removeEventListener(MouseEvent.CLICK, _parent.onAdClick);
			
			parameters.debug("AD: Skip button clicked in container");
			clean_container();
			sendEvent(AdriverEvent.SKIPPED);
			_parent.dispatchEvent(new AdriverEvent(AdriverEvent.SKIPPED));
		}
		
		public function loadBanner(url:String, x:int, y:int, isSWF:Boolean=false):void
		{			
			parameters.debug("AD: Loading banner");
			var loader:Loader = new Loader();
			configureListeners(loader.contentLoaderInfo);
			var request:URLRequest = new URLRequest(url);
			loader.load(request);
			loader.x = x;
			loader.y = y;
			addChild(loader);
			
			loaders.push(loader);
			
			sendEvent(AdriverEvent.STARTED);
		}
		
		private function connectStream():void 
		{
			stream = new NetStream(connection);
			stream.client = new Object();
			stream.addEventListener(NetStatusEvent.NET_STATUS, netStatusHandler);
			stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
			var video:Video = new Video();
			video.attachNetStream(stream);
			stream.play(_video_url);
			addChild(video);
			
			loaders.push(video);
			
			parameters.debug("AD: ..video size: "+video.width+"x"+video.height);
			
			prepare_container(video.width, video.height);
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
				parameters.debug("AD: Logging adriver event: " +event);
				//var request:URLRequest = new URLRequest(parameters.eventUrl+AdriverEvent.EventMap[event]);
//				var loader:URLLoader = new URLLoader();
//				loader.load(request);				
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
