package com.grapefrukt.games.juicy {
	import com.grapefrukt.games.general.collections.GameObjectCollection;
	import com.grapefrukt.games.general.particles.ParticlePool;
	import com.grapefrukt.games.general.particles.ParticleSpawn;
	import com.grapefrukt.games.juicy.effects.particles.BallImpactParticle;
	import com.grapefrukt.games.juicy.events.JuicyEvent;
	import com.grapefrukt.games.juicy.gameobjects.Ball;
	import com.grapefrukt.games.juicy.gameobjects.Block;
	import com.grapefrukt.games.juicy.gameobjects.Paddle;
	import com.grapefrukt.Timestep;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.ui.Keyboard;
	
	/**
	 * ...
	 * @author Martin Jonasson, m@grapefrukt.com
	 */
	public class Main extends Sprite {
		
		private var _blocks		:GameObjectCollection;
		private var _balls		:GameObjectCollection;
		private var _timestep	:Timestep;
		private var _screenshake:Shaker;
		
		private var _paddle		:Paddle;
		
		private var _particles_impact:ParticlePool;
		
		private var _mouseDown	:Boolean;
		private var _mouseVector:Point;

		private var _toggler	:Toggler;
		
		public function Main() {
			_blocks = new GameObjectCollection();
			_blocks.addEventListener(JuicyEvent.BLOCK_DESTROYED, handleBlockDestroyed, true);
			addChild(_blocks);
			
			_balls = new GameObjectCollection();
			_balls.addEventListener(JuicyEvent.BALL_COLLIDE, handleBallCollide, true);
			addChild(_balls);
			
			_particles_impact = new ParticlePool(BallImpactParticle, 20);
			addChild(_particles_impact);
			
			addEventListener(Event.ENTER_FRAME, handleEnterFrame);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, handleKeyDown);
			stage.addEventListener(MouseEvent.MOUSE_DOWN, handleMouseToggle);
			stage.addEventListener(MouseEvent.MOUSE_UP, handleMouseToggle);
			
			_timestep = new Timestep();
			_timestep.gameSpeed = 1;
			
			_mouseVector = new Point;
			
			_screenshake = new Shaker(this);
			
			_toggler = new Toggler(Settings);
			parent.addChild(_toggler);
			
			reset();
		}
		
		public function reset():void {
			graphics.clear();
			graphics.beginFill(Settings.COLOR_BACKGROUND);
			graphics.drawRect(0, 0, Settings.STAGE_W, Settings.STAGE_H);
			
			_blocks.clear();
			_balls.clear();
			
			_particles_impact.clear();
			
			for (var j:int = 0; j < Settings.NUM_BALLS; j++) {
				_balls.add(new Ball(Settings.STAGE_W / 2, Settings.STAGE_H / 2));				
			}
			
			for (var i:int = 0; i < 80; i++) {
				var block:Block = new Block( 120 + (i % 10) * (Settings.BLOCK_W + 10), 47.5 + int(i / 10) * (Settings.BLOCK_H + 10));
				_blocks.add(block);
			}
			
			_paddle = new Paddle();
			_blocks.add(_paddle);
		}
		
		private function handleEnterFrame(e:Event):void {
			_timestep.tick();
			
			_balls.update(_timestep.timeDelta);
			_blocks.update(_timestep.timeDelta);
			_screenshake.update(_timestep.timeDelta);
			
			_paddle.x = mouseX;
			
			for each(var ball:Ball in _balls.collection) {
				if (ball.x < 0 && ball.velocityX < 0) ball.collide(-1, 1);
				if (ball.x > Settings.STAGE_W && ball.velocityX > 0) ball.collide( -1, 1);
				if (ball.y < 0 && ball.velocityY < 0) ball.collide(1, -1);
				if (ball.y > Settings.STAGE_H && ball.velocityY > 0) ball.collide(1, -1);
				
				if (_mouseDown) {
					_mouseVector.x = (ball.x - mouseX) * Settings.MOUSE_GRAVITY_POWER * _timestep.timeDelta;
					_mouseVector.y = (ball.y - mouseY) * Settings.MOUSE_GRAVITY_POWER * _timestep.timeDelta;
					if (_mouseVector.length > Settings.MOUSE_GRAVITY_MAX) _mouseVector.normalize(Settings.MOUSE_GRAVITY_MAX);
					
					ball.velocityX -= _mouseVector.x;
					ball.velocityY -= _mouseVector.y;
				}
				
				// hard limit for min vel
				if (ball.velocity < Settings.BALL_MIN_VELOCITY) {
					ball.velocity = Settings.BALL_MIN_VELOCITY;
				}
				
				// soft limit for max vel
				if (ball.velocity > Settings.BALL_MAX_VELOCITY) {
					ball.velocity -= ball.velocity * Settings.BALL_VELOCITY_LOSS * _timestep.timeDelta;
				}
				
				for each ( var block:Block in _blocks.collection) {
					// check for collisions
					if (block.collidable && isColliding(ball, block)) {
						
							// back the ball out of the block
							var v:Point = new Point(ball.velocityX, ball.velocityY);
							v.normalize(2);
							while (isColliding(ball, block)) {
								ball.x -= v.x;
								ball.y -= v.y;
							}
							
							block.collide(ball);
							
							// figure out which way to bounce
							
							// slicer powerup
							if (Settings.POWERUP_SLICER_BALL && !(block is Paddle))
							ball.collide(1, 1, block);
							// top
							else if (ball.y <= block.y - block.collisionH / 2 && ball.velocityY > 0) ball.collide(1, -1, block);
							// bottom
							else if (ball.y >= block.y + block.collisionH / 2 && ball.velocityY < 0) ball.collide(1, -1, block);
							// left
							else if (ball.x <= block.x - block.collisionW / 2) ball.collide(-1, 1, block);
							// right
							else if (ball.x >= block.x + block.collisionW / 2) ball.collide(-1, 1, block);
							// wtf!
							else ball.collide(-1, -1, block);
							
							break; // only collide with one block per update
						}
				}
				
				ball.updateTrail();
			}
		}
		
		private function isColliding(ball:Ball, block:Block):Boolean {
			return 	ball.x > block.x - block.collisionW / 2 && ball.x < block.x + block.collisionW / 2 &&
					ball.y > block.y - block.collisionH / 2 && ball.y < block.y + block.collisionH / 2
		}
		
		private function handleBallCollide(e:JuicyEvent):void {
			if (Settings.EFFECT_PARTICLE_BALL_COLLISION) {
				ParticleSpawn.burst(	
					e.ball.x, 
					e.ball.y, 
					5, 
					90, 
					-Math.atan2(e.ball.velocityX, e.ball.velocityY) * 180 / Math.PI, 
					e.ball.velocity * 5, 
					.5,
					_particles_impact
				);
			}
			
			_screenshake.shake( -e.ball.velocityX * Settings.EFFECT_SCREEN_SHAKE_POWER, -e.ball.velocityY * Settings.EFFECT_SCREEN_SHAKE_POWER);
			
			e.ball.velocity = Settings.BALL_MAX_VELOCITY;
		}
		
		private function handleBlockDestroyed(e:JuicyEvent):void {
			
		}
		
		private function handleKeyDown(e:KeyboardEvent):void {
			if (e.keyCode == Keyboard.SPACE) reset();
			if (e.keyCode == Keyboard.S) _screenshake.shakeRandom(4);
		}
		
		private function handleMouseToggle(e:MouseEvent):void {
			_mouseDown = e.type == MouseEvent.MOUSE_DOWN;
		}
		
	}
	
}