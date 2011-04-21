package
{
	import adriver.*;
	import adriver.events.*;
	
	import fl.controls.TextArea;
	
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	
	public class site extends MovieClip
	{
		private var parameters:Object;
		public static var debugger:TextArea;
		public var glass_container:Sprite;
		
		public function site()
		{
			super();
			this.addEventListener(Event.ADDED_TO_STAGE, onAddedToStage); 
		}
		
		private function onAddedToStage(e:Event):void 
		{ 
			init_debbuger();
			var YOUR_SITE_ID_IN_ADRIVER:Number = 170560;
			
			// user information must be provided if you want to target
			var user_info:Object = {
					// sex of user. 2 is male. 1 is female
					// mandatory
					sex: 2,
					// birth date in "YYYY-MM-DD" format
					// mandatory
					bdate: "1917-01-09",
					// unique user identificator
					uid: 1,
					// city name. lowercase
					city_name: "st.petersburg",
					// country name. lowercase
					country_name: "russia"
				};	
				
			parameters = {
				// user information, can be left blank if you use AdriverVK to load user info
				user: user_info,			
				
				// adriver parameters
				adriver: {
					// your site id in adriver
					// mandatory
					sid: YOUR_SITE_ID_IN_ADRIVER,

					// custom parameters to provide extra targeting information
//					custom: {
//						10: user_info.city_name,
//						11: user_info.country_name,
//						12: user_info.uid
//					}

					// or we can use information from vkontakte 
					custom: {
						10: adriverLoaderDefaults.CITY_NAME,
						11: adriverLoaderDefaults.COUNTRY_NAME,
						12: adriverLoaderDefaults.UID
					}
				},
				
				// what social network to query for user data. 
				// currently only vkontakte is supported. 
				// can be commented out if you don't want module to perform query or 
				// want to supply information yourself (fill user module)
				// 
				social_network: "vkontakte",
						
				// when debugging vkontakte application locally, use test mode
				// api_test_mode: 1,
		
				// type of advertisement 
				// currently only "pregame" 
				ad_type: "pregame",
		
				// skip button settings
				// either "true" to use standard button
				// or points to actual Button in application		
				// default: true, which means create vkontakte button

				// skip_button: false,
				skip_button: true,
				// skip_button: mySkip,
				
				// label
				skip_button_label: "Skip",
				
				// how quickly it can be activated (in seconds) 
				// default: 0 which means button is active straight away
				skip_button_timeout: 0,
				
				// advertisement duration limit in seconds
				// it auto-skips the ad when timer is reached
				// default 0 which means no limit
				max_duration: 0,

				// if you want to capture clicks before they are passed to flash banner, set it to true
				// default: true, which means we don't let flash banners handle own clicks		
				catch_clicks: true,

				// style parameters
				style: {
					width: stage.width,
					height: stage.height
				},				
				
				// debug function
				debug: debug
			};
	
			show_dark_glass();
			this.setChildIndex(mc_with_ad, this.numChildren-1);
			
			// initialising adriver module with external movie clip object and parameters
			var ad:adriverLoader = new adriverLoader(mc_with_ad, parameters);
			ad.addEventListener(AdriverEvent.STARTED, onAdStarted);
			ad.addEventListener(AdriverEvent.CLICKED, onAdClicked);			
			ad.addEventListener(AdriverEvent.FINISHED, onAdFinished);
			ad.addEventListener(AdriverEvent.FAILED, onAdFailed);
			ad.addEventListener(AdriverEvent.LOADED, onAdLoaded);
			ad.addEventListener(AdriverEvent.SKIPPED, onAdSkipped);
			ad.addEventListener(AdriverEvent.PROGRESS, onAdProgress);
			ad.addEventListener(AdriverEvent.LIMITED, onAdLimited);
			ad.loadAd();
			
		}
		
		// events
		
		private function onAdStarted(event:Event):void 
		{
			debug("APP: Ad started");
		}
		
		private function onAdClicked(event:Event):void 
		{
			debug("APP: Ad clicked");
			onAdFinished(event);
		}
		
		private function onAdLimited(event:Event):void 
		{
			debug("APP: Ad limited");
			onAdFinished(event);
		}
		
		private function onAdFinished(event:Event):void 
		{
			debug("APP: Ad finished");
			// remove ad container
			removeChild(mc_with_ad);
			// remove skip button
			remove_dark_glass();
			// show app content
			_content.x = 0;
			_content.y = 0;
		}
		
		private function onAdFailed(event:Event):void 
		{
			debug("APP: Ad failed");
			onAdFinished(event);
		}
		
		private function onAdLoaded(event:Event):void
		{
			debug("APP: Ad loaded");
		}
		
		private function onAdSkipped(event:AdriverEvent):void 
		{
			debug("APP: Ad skipped");
			onAdFinished(event);
		}
		
		private function onAdProgress(event:Event):void 
		{
			debug("APP: Ad is loading...");
		}
		
		// debbuger
		
		private function init_debbuger():void 
		{
			var message:TextArea = new TextArea();
			message.width = 400;
			message.height = 300;
			message.x = 395;
			message.y = 95;
			addChild(message);
			debugger = message;
			debug("APP: Loaded");
		}
		
		private function debug(text:String):void 
		{
			debugger.text += text + "\n";
			trace(text);
		}
		
		private function show_dark_glass():void 
		{
			glass_container = new Sprite();
			addChild(glass_container);
			glass_container.graphics.beginFill( 0x000000, .5 );
			glass_container.graphics.drawRect( 0, 0, parameters.style.width, parameters.style.height );
			glass_container.graphics.endFill();
			this.setChildIndex(glass_container, this.numChildren-1);
		}
		
		private function remove_dark_glass():void 
		{
			removeChild(glass_container);
		}
		
	}
}
