package adriver
{
	
	import adriver.AdContainer;
	import adriver.events.AdriverEvent;
	import adriver.events.AdriverXMLEvent;
	
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.system.Capabilities;
	import flash.ui.Mouse;

	public class adriverLoader extends Sprite
	{
		private const VERSION:String = "1.0";		
		private const ADRIVER_URL = "http://ad.adriver.ru/cgi-bin/xmerle.cgi?";

		private const PREGAME:String = "pregame";

		private var _mc:MovieClip;
		private var parameters:Object;
		private var obj:Object;
		private var ad_cont:AdContainer;
		
		public function adriverLoader(mc:MovieClip, p:Object)
		{			
			super();
			parameters = p; 
			mc.addChild(this);			
			parameters.debug("LOADER: adriverLoader added to stage");
		}
		
		public function loadAd():void 
		{		
			if (parameters.ad_type == PREGAME) {
				parameters.debug("LOADER: Loading PREGAME ad");
				_loadAd();
			} 
			else {
				parameters.debug("LOADER: Loading default ad");
				_loadAd();	
			}
		}

		private function _loadAd():void 
		{
			// create request to adriver
			var custom_list:Object = [];
			var param_custom:String;
			var now:Number = new Date().getFullYear();
			custom_list[255] = this.VERSION;
			custom_list[254] = Capabilities.version;
			custom_list[100] = parameters.user.sex ? parameters.user.sex == 2 ? 'm' : 'f' : null;
			custom_list[101] = now - (parseInt(('' + parameters.user.bdate).split('.').pop()) || now);
			custom_list[10] = parameters.user.city_name;
			custom_list[11] = parameters.user.country_name;
			custom_list[12] = parameters.user.uid;
			param_custom = get_right_custom(custom_list);
			
			if (!parameters.adriver["sid"])
				parameters.debug("LOADER: sid is mandatory, you have forgotten it, xml error will follow");
				
			// build adriver params
			var b = [], i=0, adriverParms="";
			
			for (i in parameters.adriver) {
				b.push(i + '=' + escape(parameters.adriver[i]));
			}
			
			b.push("bt=54");
			b.push("rnd="+Math.round(Math.random()*100000000));
			adriverParms = b.join('&');
			var adriver_parameters:String;

			if (param_custom) {
				adriverParms += param_custom;  
			} 
			
			//parameters.adriver_url = ADRIVER_URL + adriverParms;
			parameters.debug("LOADER: XML url: "+ADRIVER_URL + adriverParms);
			var xml_loader:AdriverGetObjectFromXML = new AdriverGetObjectFromXML(parameters.debug);
			xml_loader.addEventListener(AdriverXMLEvent.SUCCESS, onScenarioXMLLoad);
			xml_loader.addEventListener(AdriverXMLEvent.ERROR, onScenarioXMLError);
			xml_loader.loadXML(ADRIVER_URL + adriverParms);
		}
		
		private function onScenarioXMLError(event:AdriverXMLEvent):void
		{
			parameters.debug("LOADER: XML loading or parsing errors. "+ event);
			this.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
		}
		
		private function onScenarioXMLLoad(event:AdriverXMLEvent):void
		{
			
			obj = event.obj;
			var video_url:String = obj.flv;
			var image_url:String = obj.image;
			var swf_url:String = obj.swf;
			parameters.eventUrl = obj.ar_event;

			if (video_url || image_url || swf_url) {
				
				parameters.debug("LOADER: Init container: ");
				
				ad_cont = new AdContainer(parameters, this);
				this.addChild(ad_cont);
				
				ad_cont.addEventListener(MouseEvent.CLICK, onAdClick);
				ad_cont.addEventListener(AdriverEvent.STARTED, sendPixels);
				
				
				if (video_url) {
					parameters.debug("LOADER: Trying to add a video: "+video_url);
					ad_cont.showVideo(video_url);	
				} else if (image_url) {
					parameters.debug("LOADER: Trying to add an image: "+image_url);
					ad_cont.loadBanner(image_url, 0, 0);
				} else if (swf_url) {
					parameters.debug("LOADER: Trying to add a swf: "+swf_url);
					ad_cont.loadBanner(swf_url + '?link1=' + obj.ar_cgihref, 0, 0, true)
				}
				
			} else {
				parameters.debug("LOADER: Empty banner");				
			}
		}
		
		public function onAdClick(event:MouseEvent):void {
			parameters.debug("LOADER: Ad clicked in loader ");
			
			if (ad_cont.isAdMount) {
				ad_cont.clean_container();
			}
			
			obj.makeClick();
		}
		
		private function sendPixels():void
		{			
			if(obj.pixel1) {
				parameters.debug("LOADER: pulling pixel 1");
					
				var loader:Loader = new Loader();
				var request:URLRequest = new URLRequest(obj.pixel1);
				loader.load(request);
			}
			
			if(obj.pixel2) {
				parameters.debug("LOADER: pulling pixel 2");
					
				var loader2:Loader = new Loader();
				var request2:URLRequest = new URLRequest(obj.pixel2);
				loader2.load(request2);
			} 
		}
		
		private function get_right_custom(custom:Object):String 
		{
			var j:int;
			var s:Object = [];

			for ( var i:int=0; i < custom.length; i++) {
				if (custom[i]) { 
					s.push( (!j?(j=1,i+'='):'')+escape(custom[i]));
				} 
				else {
					j=0;
				}
			}	
			
			return s.length?'&custom='+s.join(';'):''
		}
	}
}