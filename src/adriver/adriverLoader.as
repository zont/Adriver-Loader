package adriver{

	import adriver.AdContainer;
	import adriver.adriverLoaderDefaults;
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
	import vkontakte.vk.ui.VKButton;

	public class adriverLoader extends Sprite {
		private const VERSION:String = "1.9";
		private var ADRIVER_URL = "http://ad.adriver.ru/cgi-bin/xmerle.cgi?";

		private const PREGAME:String = "pregame";

		private var _mc:MovieClip;
		private var parameters:Object;
		private var obj:Object;
		private var ad_cont:AdContainer;
	
		public var skip_button:DisplayObject;
		
		public function adriverLoader(mc:MovieClip, p:Object, url:String=''){
			super();
			parameters = p;
			parameters.debug = parameters.debug || function(s){trace(s)};
			parameters.adriver.custom = parameters.adriver.custom || {};
			parameters.user = parameters.user || {};

			ADRIVER_URL = url || ADRIVER_URL;

			mc.addChild(this);
			parameters.debug("LOADER: adriverLoader added to stage");
		}

		public function loadAd():void {
			if (parameters.social_network == 'vkontakte') {
				if (parameters.wrapper) {
					parameters.debug("APP: get wrapper from params")
					vkontakte_wrapper = parameters.wrapper;
					if (vkontakte_wrapper.application) {
						app = vkontakte_wrapper.application;
					} else {
						parameters.debug("APP: wrapper from params is wrong");
					}
				} else {
					parameters.debug("APP: no wrapper in params")
					var vkontakte_wrapper: Object = Object(parent.parent.parent),
						app;
					try {
						app = vkontakte_wrapper.application;
					}
					catch(e){
						app = false;
					}
				}
				if (app) {
					parameters.debug("APP: App has vkontakte wrapper. test mode = " + parameters.api_test_mode);
					parameters["vkontakte_hasWrapper"] = true;
					parameters["vkontakte_wrapper"] = vkontakte_wrapper;
					parameters["flashVars"] = vkontakte_wrapper.application.parameters;
				}
				else {
					parameters.debug("APP: App has no vkontakte wrapper. test mode = " + parameters.api_test_mode);
					parameters["vkontakte_hasWrapper"] = false;
					if (stage && stage.loaderInfo && stage.loaderInfo.parameters) {
						parameters["flashVars"] = stage.loaderInfo.parameters as Object;
					}
					if (!parameters["flashVars"]["viewer_id"]) {
						parameters["flashVars"]["viewer_id"] = "1";
						parameters["flashVars"]["api_id"] = parameters.api_id;
						parameters["flashVars"]["secret"] = parameters.api_secret;
						parameters["flashVars"]["api_test_mode"] = parameters.api_test_mode;
					}
				}

				var module_vk:AdriverVK = new AdriverVK();
				module_vk.init(parameters);
				module_vk.commandGetProfiles(onUserInfoFull, onUserInfoEmpty);
			}
			else _loadAd();
		}

		private function onUserInfoFull(obj:Object):void {
			parameters.debug("APP: Received VK user info");
			parameters.user = obj;

			for(var i in parameters.adriver.custom) {
				if (parameters.adriver.custom[i] is Array) parameters.adriver.custom[i] = parameters.user[parameters.adriver.custom[i][0]].toLocaleLowerCase()
			}

			_loadAd();
		}

		private function onUserInfoEmpty():void {
			parameters.debug("APP: Did not receive VK user info");
			_loadAd();
		}

		private function _loadAd():void {
			if (parameters.ad_type == PREGAME) {
				parameters.debug("LOADER: Loading PREGAME ad");
			}
			else {
				parameters.debug("LOADER: Loading default ad");
			}



			// create request to adriver
			var custom_list:Object = [];

			// add extra stuff from parameters object
			for (i in parameters.adriver.custom) {
				if (!(parameters.adriver.custom[i] is Array)) custom_list[i] = parameters.adriver.custom[i];
			}

			custom_list[255] = this.VERSION;
			custom_list[254] = Capabilities.version;
			custom_list[100] = parameters.user.sex ? (parameters.user.sex == 2 ? 'm' : parameters.user.sex == 1 ?'f': null) : null;

			if (parameters.user.bdate && parameters.user.bdate.split('.').length == 3) {
				var n = new Date(),
					d = parameters.user.bdate.split('.'),
					res = n.getFullYear() - parseInt(d[2]);

				if (parseInt(d[1]) - 1 > n.getMonth() || (parseInt(d[1]) - 1 == n.getMonth() && parseInt(d[0]) > n.getDate())) res--;
				custom_list[101] = res;
			}

			var param_custom:String = get_right_custom(custom_list);

			if (!parameters.adriver["sid"])
				parameters.debug("LOADER: sid is mandatory, you have forgotten it, xml error will follow");

			// build adriver params
			var b = [], i=0, adriverParms="";

			for (i in parameters.adriver) {
				if(typeof(parameters.adriver[i]) == 'object') continue;
				b.push(i + '=' + escape(parameters.adriver[i]));
			}

			b.push("bt=54");
			b.push("rnd="+Math.round(Math.random()*100000000));
			adriverParms = b.join('&');
			var adriver_parameters:String;

			if (param_custom) {
				adriverParms += param_custom;
				parameters.wholecustom = param_custom;
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

		private function onScenarioXMLLoad(event:AdriverXMLEvent):void {

			obj = event.obj;
						
			var video_url:String = obj.flv;
			var image_url:String = obj.image;
			var swf_url:String = obj.swf;
			
			// custom passing
			parameters.eventUrl = obj.ar_event + (parameters.wholecustom || '') + "&type=";			
			obj.ar_cgihref += parameters.wholecustom || '';

			if (video_url || image_url || swf_url) {

				parameters.debug("LOADER: Init container: ");

				ad_cont = new AdContainer(parameters, this);
				this.addChild(ad_cont);

				ad_cont.addEventListener(AdriverEvent.LOADED, sendPixels);

                                ad_cont.buttonMode = true;
                                ad_cont.useHandCursor = true;

				if (video_url) {
					ad_cont.addEventListener(MouseEvent.CLICK, onAdClick);
					parameters.debug("LOADER: Trying to add a video: "+video_url);
					ad_cont.showVideo(video_url);
				}
				else if (image_url) {
					ad_cont.addEventListener(MouseEvent.CLICK, onAdClick);
					parameters.debug("LOADER: Trying to add an image: "+image_url);
					ad_cont.loadBanner(image_url, 0, 0);
				}
				else if (swf_url) {
					if (parameters.catch_clicks) {
						parameters.debug("LOADER: Won't pass clicks to flash banner");
						ad_cont.addEventListener(MouseEvent.CLICK, onAdClick);
						ad_cont.mouseChildren = false;
					}
					parameters.debug("LOADER: Trying to add a swf: " + swf_url + '?link1=' + escape(obj.ar_cgihref));
					ad_cont.loadBanner(swf_url + '?link1=' + escape(obj.ar_cgihref + '&rleurl='), 0, 0, true)
				}

			} else {
				parameters.debug("LOADER: Empty banner");
				this.dispatchEvent(new AdriverEvent(AdriverEvent.FAILED));
			}
		}

		public function onAdClick(event:MouseEvent):void {
			parameters.debug("LOADER: Ad clicked in loader ");

			if (ad_cont.isAdMount&&parameters.ad_type == PREGAME) {
				ad_cont.clean_container();
			}

			this.dispatchEvent(new AdriverEvent(AdriverEvent.CLICKED));
			obj.makeClick();
		}

		private function sendPixels(event:AdriverEvent):void
		{
			parameters.debug("LOADER: third party pixels");

			var temp = function(e:Event):void {
				trace(e + '\n');
			}
				
			if(obj.pixel1) {
				parameters.debug("LOADER: loading pixel 1");
				
				var loader:Loader = new Loader();
				loader.addEventListener(IOErrorEvent.IO_ERROR, temp);
				var request:URLRequest = new URLRequest(obj.pixel1);
				loader.load(request);
			}

			if(obj.pixel2) {
				parameters.debug("LOADER: loading pixel 2");

				var loader2:Loader = new Loader();
				loader2.addEventListener(IOErrorEvent.IO_ERROR, temp);
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
