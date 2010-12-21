package adriver.events
{
	import flash.events.Event;
	import flash.utils.Dictionary;
	
	public class AdriverEvent extends Event
	{
		public static const GET_PREROLL_LINK:String = "get_link";
		public static const STARTED:String = "started";
		public static const FINISHED:String = "finished";
		public static const LIMITED:String = "limited";
		public static const FAILED:String = "failed";
		public static const LOADED:String = "loaded;"
		public static const SKIPPED:String = "skipped";
		public static const PROGRESS:String = "progress";
		
		public function AdriverEvent(type:String)
		{
			super(type);
		}
		
		public static function getEventID(type:String):String {
			
			var	eventToNumber:Dictionary = new Dictionary();
			eventToNumber[AdriverEvent.STARTED] = 0;
			eventToNumber[AdriverEvent.FINISHED] = 1;
			eventToNumber[AdriverEvent.SKIPPED] = 2;
			eventToNumber[AdriverEvent.LIMITED] = 3;
			eventToNumber[AdriverEvent.FAILED] = 9;
			
			if (eventToNumber[type]) {
				return String(eventToNumber[type]);
			} 
			
			return String(255);
		} 
			
		public override  function clone():Event {
			return new AdriverEvent(type);
		}
	}
}
