local EnvironmentClock = {}

EnvironmentClock.Sunrise = 6
EnvironmentClock.Sunset = 18
EnvironmentClock.TwilightHours = 1

function EnvironmentClock.normalize(hour)
	return ((tonumber(hour) or 0) % 24 + 24) % 24
end

-- A continuous daylight value avoids a harsh visual jump at sunrise or sunset.
-- It is fully bright from 07:00 to 17:00 and fades through one-hour twilight
-- either side of the configured 06:00-18:00 daytime window.
function EnvironmentClock.daylight(hour)
	hour = EnvironmentClock.normalize(hour)
	local sunrise = EnvironmentClock.Sunrise
	local sunset = EnvironmentClock.Sunset
	local twilight = EnvironmentClock.TwilightHours
	if hour >= sunrise + twilight and hour <= sunset - twilight then
		return 1
	elseif hour >= sunrise - twilight and hour < sunrise + twilight then
		return math.clamp((hour - (sunrise - twilight)) / (twilight * 2), 0, 1)
	elseif hour > sunset - twilight and hour <= sunset + twilight then
		return math.clamp(((sunset + twilight) - hour) / (twilight * 2), 0, 1)
	end
	return 0
end

function EnvironmentClock.isDay(hour)
	hour = EnvironmentClock.normalize(hour)
	return hour >= EnvironmentClock.Sunrise and hour < EnvironmentClock.Sunset
end

function EnvironmentClock.fromLocalDate(localDate)
	return EnvironmentClock.normalize(
		(localDate.Hour or 0)
			+ (localDate.Minute or 0) / 60
			+ (localDate.Second or 0) / 3600
	)
end

return table.freeze(EnvironmentClock)
