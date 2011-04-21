package adriver {
	import adriver.events.AdriverXMLEvent;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.external.ExternalInterface;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.navigateToURL;
	import flash.net.sendToURL;

	internal class AdriverGetObjectFromXML extends EventDispatcher {	
		
		private var _debug:Function;
		
		public var ar_cgihref:String = "";
		public var ar_comppath;
		public var ar_event;
		public var ar_name;
		public var ar_rnd:String = "";
		public var ar_stages_trg:Object = [0,0,0,0,0,0,0,0,0,0];
		public var ar_tns_pixel:String = null;
		public var ar_zero_comppath;
		
		public var xml:XML;
		
		public var swf:String;
		public var flv:String;
		public var image:String;
		public var pixel1:String;
		public var pixel2:String;
		
		private var _parent:Object;
		
		public function AdriverGetObjectFromXML(debug:Function)
		{
			_debug = debug;
		}
		
		private function repRnd(url:String):String 
		{
			return url.split('![rnd]').join('' + this.ar_rnd);
		}
		
		internal function makeClick(url:String=null):void 
		{
			try {
				_debug("XML: Processing click");
				url = this.ar_cgihref + '&rleurl=' + escape(url || '');
				_debug("XML: navigating to URL: "+url);
				navigateToURL(new URLRequest(url), '_blank');
			} catch (error:Error) {
				dispatchEvent(new AdriverXMLEvent(AdriverXMLEvent.ERROR, error));
			}
		}
		
		private function sendEvent(stage:int):void 
		{
  			if (this.ar_stages_trg[stage] == 0) {
   				this.ar_stages_trg[stage] = 1;
    			sendPixel(this.ar_event + stage);
  			}
		}
		
		private function sendPixel(u:String = null):void 
		{
			if (!u) {
				return;
			}
		  
		  sendToURL(new URLRequest(this.repRnd(u)));
		}
		
		public function loadXML(url:String) 
		{
			var loader = new URLLoader();

			url = repRnd(url);
			loader.addEventListener(Event.COMPLETE, onXMLLoadSuccess);
			loader.addEventListener(IOErrorEvent.IO_ERROR, onXMLLoadError);
			loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onXMLLoadError);
			loader.load(new URLRequest(url));
		
		}
		
		private function onXMLLoadError(event:Event):void 
		{
			_debug('error: ' + event);
			dispatchEvent(new AdriverXMLEvent(AdriverXMLEvent.ERROR, event));
		}
		
		private function onXMLLoadSuccess(event:Event):void 
		{
			try {
				var xml = new XML(event.target.data);
				var x = xml.elements('*')[0];
				
				this.ar_zero_comppath = String(x.child('ar_zero_comppath'));
				this.ar_comppath = String(x.child('ar_comppath'));
				this.ar_name = String(x.child('ar_name'));
				this.ar_cgihref = String(x.child('ar_cgihref'));
				this.ar_rnd = String(x.child('ar_rnd'));
				this.ar_tns_pixel = String(x.child('ar_tns_pixel'));
					
				if (this.ar_tns_pixel != "") {
					var loaderTns:URLLoader = new URLLoader();
					loaderTns.load(new URLRequest(this.ar_tns_pixel));		
				}
	
				this.ar_event = "http://ad.adriver.ru/cgi-bin/event.cgi?ntype=" + x.child('ar_ntype')
								+ "&bid=" + x.child('ar_bid')
								+ "&sid=" + x.child('ar_sid')
								+ "&bt=" + x.child('ar_bt')
								+ "&ad=" + x.child('ar_adid')
								+ "&nid=" + x.child('ar_netid')
								+ "&rnd=" + x.child('ar_rnd')
								+ "&sliceid=" + x.child('ar_sliceid');
	
				var second_url:String = this.ar_comppath + this.ar_name;
				var loader = new URLLoader();
				
				loader.addEventListener(Event.COMPLETE, onSecondXMLLoadSuccess);
				loader.addEventListener(IOErrorEvent.IO_ERROR, onXMLLoadError);
				loader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onXMLLoadError);
				loader.load(new URLRequest(second_url));
			} catch (error:Error) {
				dispatchEvent(new AdriverXMLEvent(AdriverXMLEvent.ERROR, error));
			} 
			
		}
			
		private function get_path(obj, s, v)
		{
			// this is pure evil code, never write like this please
			var _ = s.child('content_'+v), c = '' + _.child('localUrl');
			
			return obj.repRnd(c&&c!='' ? obj['ar_zero_comppath'] + c : _.child('locationUrl'));
		}
			
		private function onSecondXMLLoadSuccess(event:Event):void 
		{		
			var xml = new XML(event.target.data);
			
			this.xml = xml;

			this.flv = get_path(this, xml, 'flv');
			this.swf = get_path(this, xml, 'swf');
			this.image = get_path(this, xml, 'image');

			this.pixel1 = '' + xml.child('pixelCounter').child('counter1');
			this.pixel2 = '' + xml.child('pixelCounter').child('counter2');
						
			dispatchEvent(new AdriverXMLEvent(AdriverXMLEvent.SUCCESS, this));
		}
	}
}